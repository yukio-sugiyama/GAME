#!/bin/bash

# Read configuration file
source auto_delegate.conf

#####################
# logging function
#####################
function logging() {
    LEVEL=$1
    MESSAGE=$2

    case ${LEVEL} in
        ${DEBUG} ) CLASS="DEBUG" ;;
        ${INFO} ) CLASS="INFO" ;;
        ${WARNING} ) CLASS="WARNING" ;;
        ${ERROR} ) CLASS="ERROR" ;;
    esac

    if test ${LEVEL} -ge ${_LOG_LEVEL} ; then
        echo -e $(date +%Y/%m/%d-%H:%M:%S) [${CLASS}] ${MESSAGE} 2>&1 | tee -a ${_LOG}
    fi
}

#####################
# wait_tx function
#####################
function wait_tx() {
    n_HEIGHT=$1
    c_TX=$2

    while true ; do

        l_HEIGHT=$(curl -s localhost:26657/status? | jq -r .result.sync_info.latest_block_height)
        if test ${n_HEIGHT} -gt ${l_HEIGHT} ; then
            sleep 10
            continue
        fi
        logging ${INFO} "check height: ${n_HEIGHT} tx: ${c_TX}"

        BLOCK=$(nibirud q block ${n_HEIGHT})
        LEN=$(echo ${BLOCK} | jq .block.data.txs | jq length)
        for ((i=0; i < ${LEN}; i++)); do
            TX=$(echo ${BLOCK} | jq -r .block.data.txs[${i}] | base64 -d | shasum -a 256 | awk '{ print $1 }')
            logging ${DEBUG} "txs: ${TX}"
            if [ ${c_TX,,} = ${TX,,} ]; then
                logging ${INFO} "found txs!"
                return
            fi
        done

        let n_HEIGHT++
    done
}

logging ${INFO} "--- process start!! ---"

if [ ! -e ${_OUTPUT_FILE} ]; then
    echo "timestamp, rewards, commission, fee" > ${_OUTPUT_FILE}
fi

# get balance
AMOUNT=$(nibirud q bank balances ${_ADDRESS} --denom=${_DENOM} --node=${_NODE} --chain-id=${_CHIN} -o json | jq -r .amount)
logging ${INFO} "now amount: ${AMOUNT}"

### get rewards & commission proccess
##########################################
logging ${INFO} "claim rewards & commission"

# height record before transaction execution
HEIGHT=$(curl -s localhost:26657/status? | jq -r .result.sync_info.latest_block_height)

# transaction execution
RES=$(echo -e "${_PASS}\n" | nibirud tx distribution withdraw-rewards ${_VALIDATOR} --from=${_KEY} --fees=${_FEE}${_DENOM} --gas=auto --gas-adjustment=1.15 --commission --node=${_NODE} --chain-id=${_CHAIN} --timeout-height=$(($(curl -s ${_NODE}/status? | jq -r .result.sync_info.latest_block_height)+10)) -y -o json)
logging ${INFO} "tx response: ${RES}"

# check return code
CODE=$(echo ${RES} | jq -r .code)
if [ -z ${CODE} ] || [ ${CODE} -ne 0 ]; then
    logging $ERROR "rewards & commission claim error \n${RES}"
    exit 1
fi

# Wait for transaction to be into block
TX_HASH=$(echo ${RES} | jq -r .txhash)
logging $INFO "rewards & commission claim tx: ${TX_HASH}"

wait_tx ${HEIGHT} ${TX_HASH}

TX_DATA=$(nibirud q tx ${TX_HASH} --node=${_NODE} --chain-id=${_CHIN} -o json)
logging $DEBUG "tx data\n${TX_DATA}"
TIMESTAMP=$(echo ${TX_DATA} | jq -r .timestamp)
REC_REWARD=$(echo ${TX_DATA} | jq -r .logs[0].events[4].attributes[0].value | sed -e "s/${_DENOM}//g")
REC_COMM=$(echo ${TX_DATA} | jq -r .logs[1].events[4].attributes[0].value | sed -e "s/${_DENOM}//g")
PAY_FEE=$(echo ${TX_DATA} | jq -r .tx.auth_info.fee.amount[0].amount)

# get balance
AMOUNT=$(nibirud q bank balances ${_ADDRESS} --denom=${_DENOM} --node=${_NODE} --chain-id=${_CHIN} -o json | jq -r .amount)
logging ${INFO} "now amount: ${AMOUNT}"

if [ $_AMOUNT_OR_REWARD  = "AMOUNT" ]; then
    DELEGATE_AMOUNT=$(( ${AMOUNT} * ${_DELEGATE_RATE}/100 ))
else
    DELEGATE_AMOUNT=$(( (${REC_REWARD} + ${REC_COMM}) * ${_DELEGATE_RATE}/100 ))
fi

if [ $(( ${AMOUNT} - ${DELEGATE_AMOUNT} )) -le ${_MIN_BALANCE} ]; then
    DELEGATE_AMOUNT=$(( ${AMOUNT} - ${_MIN_BALANCE} ))
fi

# Transaction data output
logging ${INFO} "rewards: ${REC_REWARD}, commission: ${REC_COMM}, fee: ${PAY_FEE}"
logging ${INFO} "delegate amount: ${DELEGATE_AMOUNT}"

echo "${TIMESTAMP}, ${REC_REWARD}, ${REC_COMM}, ${PAY_FEE}" >> ${_OUTPUT_FILE}

### delegate proccess
##########################################
logging ${INFO} "delegate"

# height record before transaction execution
HEIGHT=$(curl -s localhost:26657/status? | jq -r .result.sync_info.latest_block_height)

# transaction execution
RES=$(echo -e "${_PASS}\n" | nibirud tx staking delegate ${_VALIDATOR} ${DELEGATE_AMOUNT}${_DENOM} --from=${_KEY} --fees=${_FEE}${_DENOM} --gas=auto --gas-adjustment=1.15 --node=${_NODE} --chain-id=${_CHAIN} --timeout-height=$(($(curl -s ${_NODE}/status? | jq -r .result.sync_info.latest_block_height)+10)) -y -o json)
logging ${INFO} "tx response: ${RES}"

# check return code
CODE=$(echo ${RES} | jq -r .code)
if [ -z ${CODE} ] || [ ${CODE} -ne 0 ]; then
    logging ${ERROR} "delegate error \n${RES}"
    exit 1
fi

# Wait for transaction to be into block
TX_HASH=$(echo ${RES} | jq -r .txhash)
logging ${INFO} "delegate tx: ${TX_HASH}"

wait_tx ${HEIGHT} ${TX_HASH}

TX_DATA=$(nibirud q tx ${TX_HASH} --node=${_NODE} --chain-id=${_CHIN} -o json)
logging $DEBUG "tx data\n${TX_DATA}"
TIMESTAMP=$(echo ${TX_DATA} | jq -r .timestamp)
REC_REWARD=$(echo ${TX_DATA} | jq -r .logs[0].events[4].attributes[2].value | sed -e "s/${_DENOM}//g")
REC_COMM=0
PAY_FEE=$(echo ${TX_DATA} | jq -r .tx.auth_info.fee.amount[0].amount)

# Transaction data output
logging ${INFO} "rewards: ${REC_REWARD}, commission: ${REC_COMM}, fee: ${PAY_FEE}"

# get balance
AMOUNT=$(nibirud q bank balances ${_ADDRESS} --denom=${_DENOM} --node=${_NODE} --chain-id=${_CHIN} -o json | jq -r .amount)
logging ${INFO} "now amount: ${AMOUNT}"

echo "${TIMESTAMP}, ${REC_REWARD}, ${REC_COMM}, ${PAY_FEE}" >> ${_OUTPUT_FILE}
