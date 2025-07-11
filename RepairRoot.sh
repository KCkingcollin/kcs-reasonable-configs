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
    cp -rf pacman* /etc/
    pacman -Syy --noconfirm archlinux-keyring
    echo "root dir?"
    read -rp " > " rootdir
    cd "$rootdir" || return
    rootdir="$(pwd)"
    cd - || return
    # checking to make sure we are not in chroot
    if ! [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
        cd "$rootdir" || return
        cd ..
        mkdir oldfiles
        mkdir oldfiles/etc
        cd "$rootdir"/etc || return
        if ! cp -R fstab group* local* NetworkManager pacman* sudo* ssh* ssl* ../../oldfiles/etc/; then
            echo "couldn't copy some files, not attempting the whipe"
            return
        fi
        cd ..
        echo "About to whipe root and reinstall, contenue?"
        read -rp "[Y/n]: " answer
        if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]; then
            for file in *; do
                if [[ "$file" != *"home"* && "$file" != *"root"* && "$file" != *"dev"* && "$file" != *"boot"* ]]; then 
                    rm -r "$file"
                fi
            done
            rm -r boot/*
        fi
        cd ..
        pacstrap -K "$rootdir" $(cat "$archPackages")
        cd oldfiles || return
        if ! cp -Rf etc ../"$rootdir"/; then
            echo "couldn't copy some files, not attempting to install"
            return
        fi
        cd ..
        export -f chrootSetup extraPackages
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
