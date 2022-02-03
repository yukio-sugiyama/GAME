#!/bin/bash

_KEY=<your key>
_ADDRESS=<your address>
_VALIDATOR=<your validator address>
_PASS=<wallet password>
_NODE=http://localhost:26657
_CHAIN=nibiru-3000
_DENOM=ugame
_FEE=10ugame
_DELEGATE_RATE=50

_LOG=auto_delegate.log

DEBUG=10
INFO=20
WARNING=30
ERROR=40
_LOG_LEVEL=${INFO}


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
        echo -e $(date +%Y/%m/%d-%H:%M:%S) [${CLASS}] ${MESSAGE} >> ${_LOG}
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


# get balance
AMOUNT=$(nibirud q bank balances ${_ADDRESS} --denom=${_DENOM} --node=${_NODE} --chain-id=${_CHIN} -o json | jq -r .amount)
logging ${INFO} "now amount: ${AMOUNT}"

### get rewards & commission proccess
##########################################
logging ${INFO} "claim rewards & commission"

# height record before transaction execution
HEIGHT=$(curl -s localhost:26657/status? | jq -r .result.sync_info.latest_block_height)

# transaction execution
RES=$(echo -e "${_PASS}\n" | nibirud tx distribution withdraw-rewards ${_VALIDATOR} --from=${_KEY} --fees=${_FEE} --gas=auto --commission --node=${_NODE} --chain-id=${_CHAIN} --timeout-height=$(($(curl -s ${_NODE}/status? | jq -r .result.sync_info.latest_block_height)+3)) -y -o json)
logging ${DEBUG} "tx response: ${RES}"

# check return code
CODE=$(echo ${RES} | jq -r .code)
if [ ${CODE} -ne 0 ]; then
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

DELEGATE_AMOUNT=$(( (REC_REWARD+REC_COMM) * ${_DELEGATE_RATE}/100 ))

# Transaction data output
logging ${INFO} "rewards: ${REC_REWARD}, commission: ${REC_COMM}, fee: ${PAY_FEE}"
logging ${INFO} "delegate amount: ${DELEGATE_AMOUNT}"

# get balance
AMOUNT=$(nibirud q bank balances ${_ADDRESS} --denom=${_DENOM} --node=${_NODE} --chain-id=${_CHIN} -o json | jq -r .amount)
logging ${INFO} "now amount: ${AMOUNT}"


### delegate proccess
##########################################
logging ${INFO} "delegate"

# height record before transaction execution
HEIGHT=$(curl -s localhost:26657/status? | jq -r .result.sync_info.latest_block_height)

# transaction execution
RES=$(echo -e "${_PASS}\n" | nibirud tx staking delegate ${_VALIDATOR} ${DELEGATE_AMOUNT}${_DENOM} --from=${_KEY} --fees=${_FEE} --gas=auto --node=${_NODE} --chain-id=${_CHAIN} --timeout-height=$(($(curl -s ${_NODE}/status? | jq -r .result.sync_info.latest_block_height)+3)) -y -o json)
logging ${DEBUG} "tx response: ${RES}"

# check return code
CODE=$(echo ${RES} | jq -r .code)
if [ ${CODE} -ne 0 ]; then
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
