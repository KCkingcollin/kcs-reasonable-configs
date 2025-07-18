#!/bin/bash

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
    read -rp "Name of the account?: " userName
    useradd -m "$userName"
    passwd "$userName"
    groupadd sudo
    usermod -aG sudo "$userName"
    if [ "$(grep -o -m 1 "# %sudo" < /etc/sudoers)" = "# %sudo" ]
    then
        echo "%sudo	ALL=(ALL:ALL) ALL" > /etc/sudoers.d/sudo-enable 
    fi
    echo "$userName"
}

function getAccount {
    echo "Provid the account usernemae you want to set the environment up with" > $(tty)
    read -rp "Username?: " userName
    groupadd sudo
    usermod -aG sudo "$userName"
    if [ "$(grep -o -m 1 "# %sudo" < /etc/sudoers)" = "# %sudo" ]
    then
        echo "%sudo	ALL=(ALL:ALL) ALL" > /etc/sudoers.d/sudo-enable 
    fi
    echo "$userName"
}

function chrootSetup {
    genfstab -U / >> /etc/fstab
    ln -sf /usr/share/zoneinfo/Region/City /etc/localtime
    hwclock --systohc
    locale-gen
    echo "Set the root password" > $(tty)
    passwd
    systemctl enable NetworkManager
    systemctl enable gdm
    systemctl enable cronie
    pacman -Syyu --noconfirm
    grub-install --target=x86_64-efi --efi-directory=boot/efi --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    createAccount
}

function extraPackages {
    cloneRepo
    chown -R "$userName":"$userName" .

    if [ "$(pacman -Q | grep -o -m 1 yay)" != "yay" ];
    then
        if [ "$(ls | grep -o -m 1 "yay")" = "yay" ];
        then 
            rm -r ./yay/
        fi
        git clone https://aur.archlinux.org/yay.git
        chown -R "$userName":"$userName" .
        cd yay || return
        sudo -S -u "$userName" makepkg -si --noconfirm
        cd ..
    fi

    sudo -S -u "$userName" yay -S --noconfirm --nodeps $(cat "$aurPackages")

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
    homeDir=$(awk -F: -v v="$userName" '{if ($1==v) print $6}' /etc/passwd)
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

    mv /root/.config/nvim /root/.config/nvim.bac 
    mv /root/.config/fastfetch /root/.config/fastfetch.bac 
    mv /root/.config/kitty /root/.config/foot.bac 
    mv /root/.config/hypr /root/.config/hypr.bac 
    mv /root/.config/waybar /root/.config/waybar.bac 
    mv /root/.config/swaync /root/.config/swaync.bac 
    mv /root/.config/rofi /root/.config/rofi.bac 
    mv /root/.config/castle-shell /root/.config/castle-shell.bac 
    mv /root/.zshrc /root/.zshrc.bac 
    mv /root/.themes /root/.themes.bac 
    mv /root/.icons /root/.icons.bac 
    mv /root/.gtkrc-2.0 /root/.gtkrc-2.0.bac 

    sudo -S -u "$userName" mkdir "$homeDir"/.config
    yes | cp -rfp config/* /home/"$userName/.config/"
    mv "$homeDir"/.config/nvim/lua/user "$homeDir"/.config/nvim/lua/"$userName"
    yes | cp -rfp ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 /home/"$userName"/
    yes | cp -rfp ./after.sh "$homeDir"/.config/hypr/
    mv "$homeDir"/.config/hypr/hyprland.conf "$homeDir"/.config/hypr/hyprland.conf.bac
    yes | cp -rfp ./hyprland.conf.once "$homeDir"/.config/hypr/hyprland.conf

    cp -rf config/* /root/.config/
    mv /root/.config/nvim/lua/user /root/.config/nvim/lua/root
    cp -rf ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 /root/
    cp -rf ./switch-DEs.sh /usr/bin/switch-DEs
    cp -rf ./theme-check.service ./waybar-hyprland.service /usr/lib/systemd/user/
    cp -rf ./switch-DEs.service  /etc/systemd/system/
    chsh -s /bin/zsh "$userName"
    chsh -s /bin/zsh root

    if [ "$(ls "$homeDir/Pictures/" | grep -o -m 1 "background.jpg")" != "background.jpg" ];
    then
        sudo -S -u "$userName" mkdir -p "$homeDir"/Pictures
        yes | cp -fp ./background.jpg "$homeDir"/Pictures/background.jpg
    fi

    rate-mirrors --allow-root --save /etc/pacman.d/mirrorlist arch

    sudo -S -u "$userName" nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'
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
            echo "Replace repos with arch repos?"
            read -rp "[Y/n]: " answer
            if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]; then
                cp -rf etc/* /etc/
            fi
            cd /
            pacman -Syy --noconfirm archlinux-keyring arch-install-scripts
            lsblk

            echo "Auto mount partitions?"
            read -rp "[Y/n]: " answer
            if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]; then
                echo "Root partition (needs to be btrfs)?"
                read -rp " > " partRoot
                if [ "$partRoot" == "" ]; then
                    echo "No root provided, stopping installation"
                    return
                else
                    mount "$partRoot" /mnt
                    cd /mnt || return
                    btrfs subvolume create @
                fi

                echo "Home partition (leave blank to use the same partition)?"
                read -rp " > " partHome
                if [ "$partHome" == "" ]; then
                    btrfs subvolume create @home
                    cd /
                    umount /mnt
                    mount -t btrfs -o subvol=@ "$partRoot" /mnt
                    mkdir /mnt/home
                    mount -t btrfs -o subvol=@home "$partRoot" /mnt/home
                else
                    cd /
                    umount /mnt
                    mount -t btrfs -o subvol=@ "$partRoot" /mnt
                    mount "$partHome" /mnt/home
                fi

                echo "Boot partition?"
                read -rp " > " partBoot
                mkdir -p /mnt/boot/efi
                if [ "$partBoot" == "" ]; then
                    echo "Bios boot is not supported, need a fat32 efi partition"
                    return
                else
                    mount "$partBoot" /mnt/boot/efi
                fi

                echo "Swap partition?"
                read -rp " > " partSwap
                if [ "$partSwap" == "" ]; then
                    echo "Swap file not yet supported, continuing without swap"
                    swapoff -a
                else
                    swapoff -a
                    swapon "$partSwap"
                fi
            fi

            pacstrap -K /mnt $(cat "$archPackages")
            export -f chrootSetup extraPackages configSetup cloneRepo getAccount createAccount
            export gitRepo userName
            userName="$(arch-chroot /mnt /bin/bash -c chrootSetup | tail -n 1)"
            echo "Name of the machine?"
            read -rp " > " answer
            echo "$answer" > /mnt/etc/hostname
            echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
            echo "KEYMAP=us" > /etc/vconsole.conf
            arch-chroot /mnt /bin/bash -c extraPackages
            arch-chroot /mnt /bin/bash -c configSetup
            return
        fi
        cloneRepo
        echo "Replace repos with arch repos?"
        read -rp "[Y/n]: " answer
        if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]; then
            cp -rf etc/* /etc/
            pacman -Syy --noconfirm archlinux-keyring
            pacman -Syyu --noconfirm --nodeps $(cat "$archPackages")
        else
            pacman -Syyu --noconfirm $(cat "$archPackages")
        fi
        if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
            userName="$(chrootSetup | tail -n 1)"
            extraPackages
            configSetup
            return
        else
            echo "Create a new account?"
            read -rp "[Y/n]: " answer
            if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]
            then
                userName="$(createAccount | tail -n 1)"
            else
                userName="$(getAccount | tail -n 1)"
            fi
            extraPackages
            configSetup
            sudo -S -u "$userName" systemctl --user import-environment
            systemctl start switch-DEs.service
            return
        fi
    else
        echo "Need to run as root"
        return
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
