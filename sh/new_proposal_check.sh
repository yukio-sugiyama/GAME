#!/bin/bash

_NODE=http://localhost:26657
_CHAIN=nibiru-3000
_NEXT_P_ID=1 #Proposal id to start checking
_WEBHOOK_URL="https://discord.com/api/webhooks/<your discord webhook URL>"
_SLEEP_TIME=600 #in seconds

function discord_notify() {
    MESSAGE=$1
    curl \
    -X POST \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"$MESSAGE\"}" \
    "$_WEBHOOK_URL"
}

while true; do

    p_id_l=($(nibirud q gov proposals --node=$_NODE --chain-id=$_CHIN -o json | jq -r .proposals[].proposal_id))

    for p_id in "${p_id_l[@]}" ; do

        if test $p_id -ge $_NEXT_P_ID ; then
            title=$(nibirud q gov proposal $p_id --node=$_NODE --chain-id=$_CHIN -o json | jq -r .content.title)
            end_time=$(nibirud q gov proposal $p_id --node=$_NODE --chain-id=$_CHIN -o json | jq -r .voting_end_time)
            discord_notify "**Add a new proposal**\`\`\`\n　ID: $p_id\n　Title: $title\n　End: $end_time\`\`\`"
            _NEXT_P_ID=$(($p_id+1))
        fi

    done

    sleep $_SLEEP_TIME

done
