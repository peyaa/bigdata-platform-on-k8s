#!/bin/bash
failure_times=0
while true
do
    live_srv=`jps | grep 'JournalNode\|DataNode\|QuorumPeerMain\|NodeManager' | wc -l`
    if [ $live_srv -lt 4 ]; then
        ((failure_times++))
    else
        failure_times=0
        touch /tmp/healthy
    fi
    
    if [ $failure_times -eq 3 ]; then
        rm -rf /tmp/healthy
    fi

    sleep 1
done