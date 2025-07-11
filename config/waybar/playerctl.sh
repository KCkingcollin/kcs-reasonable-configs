#!/bin/bash

playerctlStatus="null"
newStatus="null"
newStatus2="null"
timer=0

# # start script at a random time between 50 and 1000 ms to prevent race condition
# min=5
# max=100
# random_value=$(( ( RANDOM % ( max - min + 1 ) ) + min ))
# # echo - | awk -v var=$random_value '{print (var/100)}'
# sleep $(echo - | awk -v var=$random_value '{print (var/100)}')

while true
do
    # set status var
   playerctlStatus=$(cat /tmp/playerctlStatus)
    # enable button if there is output
    if [ "$playerctlStatus" != "" ]; 
    then 
        if [ "$playerctlStatus" != "$newStatus" ]; 
        then 
            echo "Enabled"; 
            newStatus="$playerctlStatus"
        fi
        newStatus2="null"
    elif [ "$playerctlStatus" != "$newStatus2" ]; 
    then 
        echo ""; 
        newStatus2="$playerctlStatus"
        newStatus="$playerctlStatus"
    fi
    # send status every 5 seconds just in case
    if [ $timer -ge 20 ];
    then
        if [ "$playerctlStatus" != "" ]; 
        then 
            echo "Enabled"; 
        else 
            echo ""
        fi
        timer=0
    else
        timer=$((timer+1))
        # echo $timer
    fi
    # sleep for 250ms
    sleep 0.25
done
