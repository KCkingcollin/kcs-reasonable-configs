#!/bin/bash

source Install.sh true

if [ "$1" != "" ]; then
    gitRepo="$1"
else
    echo "need to specify a branch"
    return
fi

if [ "$USER" = 'root' ]; then
    cloneRepo
    cp -rf etc/* /etc/
    pacman -Syy --noconfirm archlinux-keyring arch-install-scripts
    echo "root dir?"
    read -rp " > " rootdir
    cd "$rootdir" || return
    rootdir="$(pwd)"
    cd - || return
    # checking to make sure we are not in chroot
    if ! [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
        echo "About to whipe root and reinstall (home and root folders will not be whiped, and etc will be coppied into oldetc), contenue?"
        read -rp "[Y/n]: " answer
        cd "$rootdir" || return
        if ! cp -R etc oldetc; then
            echo "couldn't copy some files, not attempting the whipe"
            return
        fi
        if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]; then
            for file in *; do
                if [[ "$file" != *"home"* && "$file" != *"root"* && "$file" != *"dev"* && "$file" != *"oldetc"* ]]; then 
                    rm -r "$file"
                fi
            done
        fi
        cd ..
        pacstrap -K "$rootdir" $(cat "$archPackages")
        genfstab -U "$rootdir" >> "$rootdir"/etc/fstab
        export -f chrootSetup extraPackages configSetup cloneRepo getAccount createAccount
        export gitRepo userName
        username="$(arch-chroot "$answer" /bin/bash -c chrootSetup | tail -n 1)"
        arch-chroot "$answer" /bin/bash -c extraPackages "$username"
    else
        export -f chrootSetup extraPackages
        username="$(arch-chroot "$answer" /bin/bash -c chrootSetup | tail -n 1)"
        arch-chroot "$answer" /bin/bash -c extraPackages "$username"
    fi
else
    echo "not root"
fi
