#!/bin/bash

playing="null"
curentlyPlaying="null"
newStatus="null"
playerctlStatus="null"
Status="null"
timer=0
strSizeLim=12

while true
do
    playerctlStatus=$(playerctl -s status);
    if [ "$playerctlStatus" != "" ]; 
    then 
        if [ "$playerctlStatus" != "Playing" ]; 
        then 
            icon=""; 
        else 
            icon=""; 
        fi
        artist="$(playerctl metadata --format '{{ markup_escape(artist) }}')"
        title="$(playerctl metadata --format '{{ markup_escape(title) }}')"
        playing="$icon ${artist:0:strSizeLim} - ${title:0:strSizeLim}";
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
