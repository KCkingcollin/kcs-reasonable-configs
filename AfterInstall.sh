#!/bin/bash

trap cleanup SIGINT SIGTERM

function cleanup {
    mv "$HOME/.config/hypr/hyprland.conf.bac" "$HOME/.config/hypr/hyprland.conf"
    sudo rm /etc/sudoers.d/AfterInstallRule
}

echo "Installing Required Plugins"
echo -e "\033[31mDO NOT INTERRUPT\033[0m"; 
echo -e "\033[31mSudo will temporarily be available to use without a password for this user BE CAREFUL\033[0m"; 
yes | rm -r ~/Hyprland/ &> /dev/null
git clone https://github.com/hyprwm/Hyprland.git 
yes | hyprpm -n update
yes | hyprpm -n add https://github.com/outfoxxed/hy3
yes | hyprpm -n enable hy3
yes | hyprpm -n add https://github.com/hyprwm/hyprland-plugins
yes | hyprpm -n enable hyprbars
yes | hyprpm -n enable hyprexpo
yes | hyprctl reload
mv "$HOME/.config/hypr/hyprland.conf.bak" "$HOME/.config/hypr/hyprland.conf"
sudo rm /etc/sudoers.d/AfterInstallRule
