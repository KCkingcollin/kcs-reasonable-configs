#!/bin/bash

gitRepo=""
archPackages=""
aurPackages=""

function cloneRepo {
    if [ "$(git status | grep -o -m 1 "On branch")" != "On branch" ]
    then
        if [ "$(ls | grep -o -m 1 "kcs-reasonable-configs")" = "kcs-reasonable-configs" ];
        then 
            sudo -S rm -r ./kcs-reasonable-configs/
        fi
        git clone -b "$gitRepo" https://github.com/KCkingcollin/kcs-reasonable-configs
        cd kcs-reasonable-configs || return
        archPackages="$(pwd)/arch-packages"
        aurPackages="$(pwd)/aur-packages"
    fi
}

function createAccount {
    read -rp "Name of the account?: " accountName
    useradd -m "$accountName"
    passwd "$accountName"
    groupadd sudo
    usermod -aG sudo "$accountName"
    if [ "$(grep -o -m 1 "# %sudo" < /etc/sudoers)" = "# %sudo" ]
    then
        echo "%sudo	ALL=(ALL:ALL) ALL" > /etc/sudoers.d/sudo-enable 
    fi
    echo "$accountName"
}

function getAccount {
    echo "Provid the account usernemae you want to set the environment up with"
    read -rp "Username?: " accountName
    groupadd sudo
    usermod -aG sudo "$accountName"
    if [ "$(grep -o -m 1 "# %sudo" < /etc/sudoers)" = "# %sudo" ]
    then
        echo "%sudo	ALL=(ALL:ALL) ALL" > /etc/sudoers.d/sudo-enable 
    fi
    echo "$accountName"
}

function chrootSetup {
    echo "Set the root password"
    passwd
    systemctl enable NetworkManager
    systemctl enable gdm
    systemctl enable cronie
    pacman -Syyu --noconfirm
    grub-install --target=x86_64-efi --efi-directory=boot/efi --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    genfstab -U / >> /etc/fstab
    createAccount
}

function extraPackages {
    userName=$1
    cloneRepo
    chown -R "$userName":"$userName" .

    if [ "$(pacman -Q | grep -o -m 1 yay)" != "yay" ];
    then
        if [ "$(ls | grep -o -m 1 "yay")" = "yay" ];
        then 
            rm -r ./yay/
        fi
        sudo -S -i -u "$userName" git clone https://aur.archlinux.org/yay.git
        cd yay || return
        sudo -S -i -u "$userName" makepkg -si --noconfirm
        cd ..
    fi

    sudo -S -i -u "$userName" yay -S --noconfirm $(cat "$aurPackages")

    if [ "$(ls | grep -o -m 1 "castle-shell")" = "castle-shell" ];
    then 
        rm -r ./castle-shell/
    fi
    git clone https://github.com/KCkingcollin/castle-shell
    cd castle-shell/color-checker || return
    go build -o /usr/bin/color-checker
    cd ../..

    flatpak remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak override --filesystem="/home/$userName"/.themes
    flatpak override --filesystem="/home/$userName"/.icons
    flatpak override --filesystem="/home/$userName"/.gtkrc-2.0
    flatpak override --env=GTK_THEME=Adwaita-dark
    flatpak override --env=ICON_THEME=Adwaita-dark
}

function configSetup {
    userName=$1
    homeDir=~"$userName"
    cd "$homeDir" || return
    cloneRepo
    chown -R "$userName":"$userName" .

    mv "$homeDir"/.config/nvim "$homeDir"/.config/nvim.bac 
    mv "$homeDir"/.config/fastfetch "$homeDir"/.config/fastfetch.bac 
    mv "$homeDir"/.config/kitty "$homeDir"/.config/foot.bac 
    mv "$homeDir"/.config/hypr "$homeDir"/.config/hypr.bac 
    mv "$homeDir"/.config/waybar "$homeDir"/.config/waybar.bac 
    mv "$homeDir"/.config/swaync "$homeDir"/.config/swaync.bac 
    mv "$homeDir"/.config/rofi "$homeDir"/.config/rofi.bac 
    mv "$homeDir"/.config/castle-shell "$homeDir"/.config/castle-shell.bac 
    mv "$homeDir"/.zshrc "$homeDir"/.zshrc.bac 
    mv "$homeDir"/.themes "$homeDir"/.themes.bac 
    mv "$homeDir"/.icons "$homeDir"/.icons.bac 
    mv "$homeDir"/.gtkrc-2.0 "$homeDir"/.gtkrc-2.0.bac 

    sudo -S -i -u "$userName" mkdir "$homeDir"/.config
    yes | cp -rfp config/* /home/"$userName/.config/"
    yes | cp -rfp ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 /home/"$userName/"
    yes | cp -rfp ./after.sh "$homeDir"/.config/hypr/
    mv "$homeDir"/.config/hypr/hyprland.conf "$homeDir"/.config/hypr/hyprland.conf.bac
    yes | cp -rfp ./hyprland.conf.once "$homeDir"/.config/hypr/hyprland.conf

    cp -rf config/* /root/.config/
    cp -rf ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 /root/
    cp -rf etc/* /etc/
    cp -rf ./switch-DEs.sh /usr/bin/switch-DEs
    cp -rf ./theme-check.service ./waybar-hyprland.service /usr/lib/systemd/user/
    cp -rf ./switch-DEs.service  /etc/systemd/system/
    chsh -s /bin/zsh "$userName"
    chsh -s /bin/zsh root

    if [ "$(ls "$userName/Pictures/" | grep -o -m 1 "background.jpg")" != "background.jpg" ];
    then
        sudo -S -i -u "$userName" mkdir -p "$homeDir"/Pictures
        yes | cp -fp ./background.jpg "$homeDir"/Pictures/background.jpg
    fi

    rate-mirrors --allow-root --save /etc/pacman.d/mirrorlist arch

    sudo -S -i -u "$userName" nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'
    nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

    bash -c echo '[User]                        
    Session=hyprland
    XSession=hyprland
    Icon="$userName"/.face
    SystemAccount=false' > /var/lib/AccountsService/users/"$userName"
}

function main {
    if [[ $(id -u) = 0 ]]; then
        echo "Clean install arch?"
        read -rp "[Y/n]: " answer
        if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]; then
            cloneRepo
            cp -rf etc/* /etc/
            cd /
            pacman -Syy --noconfirm archlinux-keyring arch-install-scripts
            lsblk

            echo "Root partition (needs to be btrfs)?"
            read -rp " > " partRoot
            mount "$partRoot"
            cd /mnt || return
            btrfs subvolume create @
            cd /
            umount /mnt
            mount -t btrfs -o subvol=@ "$partRoot" /mnt

            echo "Home partition (leave blank to use the same partition)?"
            read -rp " > " partHome
            mkdir /mnt/home
            if [ "$partHome" == "" ]; then
                cd /mnt || return
                btrfs subvolume create @home
                mount -t btrfs -o subvol=@home "$partHome" /mnt/home
            else
                mount "$partHome" /mnt/home
            fi

            echo "Boot partition?"
            read -rp " > " partBoot
            mkdir -p /mnt/boot/efi
            mount "$partBoot" /mnt/boot/efi

            pacstrap -K /mnt $(cat "$archPackages")
            export -f chrootSetup extraPackages configSetup cloneRepo getAccount createAccount
            export gitRepo
            userName="$(arch-chroot /mnt /bin/bash -c chrootSetup | tail -n 1)"
            arch-chroot /mnt /bin/bash -c extraPackages "$userName"
            arch-chroot /mnt /bin/bash -c configSetup "$userName"
            return
        fi
        if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
            cloneRepo
            cp -rf etc/* /etc/
            userName="$(chrootSetup | tail -n 1)"
            extraPackages "$userName"
            configSetup "$userName"
            return
        else
            echo "Create a new account?"
            read -rp "[Y/n]: " answer
            if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]
            then
                cloneRepo
                cp -rf etc/* /etc/
                accountName="$(createAccount | tail -n 1)"
                pacman -Syyu --noconfirm $(cat "$archPackages")
                extraPackages "$accountName"
                configSetup "$accountName"
                sudo -S -i -u "$accountName" systemctl --user import-environment
                systemctl start switch-DEs.service
                return
            else
                cloneRepo
                cp -rf etc/* /etc/
                accountName="$(getAccount | tail -n 1)"
                pacman -Syyu --noconfirm $(cat "$archPackages")
                extraPackages "$accountName"
                configSetup "$accountName"
                sudo -S -i -u "$accountName" systemctl --user import-environment
                systemctl start switch-DEs.service
                return
            fi
        fi
    else
        echo "Need to run as super user"
        sudo -S "$(main)"
    fi
}

# if true use the script as a set of functions basically
if [ "$1" != true ]; then 
    if [ "$1" != "" ]; then
        gitRepo="$1"
    else
        echo "need to specify a branch"
        return
    fi
    main 
fi
