#!/bin/bash

repeat=true

hyprpm -n update
hyprpm -n add https://github.com/hyprwm/hyprland-plugins
hyprpm -n enable hyprbars

while $repeat
do
    echo "Did hyprpm update without errors?"
    read -p "(y/n): " answer
    if [ "$(echo "$answer" | grep -o "y")" = "y" ]
    then
        mv "$HOME/.config/hypr/hyprland.conf.bac" "$HOME/.config/hypr/hyprland.conf"
        yay -S --noconfirm hyprland hy3
        repeat=false
    else
        yay -S --noconfirm hyprland-git hy3-git
        hyprpm -n update
        hyprpm -n add https://github.com/hyprwm/hyprland-plugins
        hyprpm -n enable hyprbars
        repeat=true
    fi
done
