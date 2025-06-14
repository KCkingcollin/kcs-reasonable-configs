#!/bin/bash

yes | rm -r ~/Hyprland/ 
git clone https://github.com/hyprwm/Hyprland.git 
yes | hyprpm -n update
yes | hyprpm -n add https://github.com/outfoxxed/hy3
yes | hyprpm -n enable hy3
yes | hyprpm -n add https://github.com/hyprwm/hyprland-plugins
yes | hyprpm -n enable hyprbars
yes | hyprpm -n enable hyprexpo
mv "$HOME/.config/hypr/hyprland.conf.bac" "$HOME/.config/hypr/hyprland.conf"

# repeat=true
#
# while $repeat
# do
#     echo "Did hyprpm update without errors?"
#     read -p "[Y/n]: " answer
#     if [ "$(echo "$answer" | grep -o "y")" = "y" ]
#     then
#         mv "$HOME/.config/hypr/hyprland.conf.bac" "$HOME/.config/hypr/hyprland.conf"
#         repeat=false
#     else
#         yes | rm -r ~/Hyprland/ 
#         git clone https://github.com/hyprwm/Hyprland.git 
#         yes | hyprpm -n update
#         yes | hyprpm -n add https://github.com/hyprwm/hyprland-plugins
#         yes | hyprpm -n add https://github.com/outfoxxed/hy3
#         yes | hyprpm -n enable hyprbars
#         yes | hyprpm -n enable hy3
#         repeat=true
#     fi
# done
