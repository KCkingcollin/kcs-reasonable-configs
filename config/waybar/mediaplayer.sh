#!/bin/bash

playing="null"
curentlyPlaying="null"
newStatus="null"
playerctlStatus="null"
Status="null"
timer=0

# # start script at a random time between 50 and 1000 ms to prevent race condition
# min=5
# max=100
# random_value=$(( ( RANDOM % ( max - min + 1 ) ) + min ));
# # echo - | awk -v var=$random_value '{print (var/100)}'
# sleep $(echo - | awk -v var=$random_value '{print (var/100)}');

while true
do
    # set the status var
    playerctlStatus=$(playerctl -s status);
    # send playing song if something is playing
    if [ "$playerctlStatus" != "" ]; 
    then 
        # set the icon
        if [ "$playerctlStatus" != "Playing" ]; 
        then 
            icon=""; 
        else 
            icon=""; 
        fi
        # set playing song after setting the icon
        playing="$icon $(playerctl -s metadata artist) - $(playerctl -s metadata title)";
        # echo whats playing if we haven't already
        if [ "$curentlyPlaying" != "$playing" ]; 
        then 
            echo "$playing"; 
            Status="Enabled"
            curentlyPlaying="$playing";
        fi
        newStatus="null"
    elif [ "$playerctlStatus" != "$newStatus" ]; 
    then 
        echo ""; 
        Status=""
        newStatus="$playerctlStatus";
        curentlyPlaying="null";
    fi
    # resend status every 5 seconds just in case
    if [ $timer -ge 20 ];
    then
        if [ "$playerctlStatus" != "" ]; 
        then 
            echo "$curentlyPlaying"; 
            Status="Enabled"
        else 
            echo "";
            Status=""
        fi
        timer=0;
    else
        timer=$((timer+1));
        # echo $timer
    fi
    echo "$Status" > /tmp/playerctlStatus
    # sleep for 250ms before runing the checks again
    sleep 0.25;
done
