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
        pwd
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
    function commands {
        cd "$(cloneRepo | tail -n 1)" || return

        if [ "$(pacman -Q | grep -o -m 1 yay)" != "yay" ];
        then
            if [ "$(ls | grep -o -m 1 "yay")" = "yay" ];
            then 
                sudo -S rm -r ./yay/
            fi
            git clone https://aur.archlinux.org/yay.git
            cd yay || return
            makepkg -si --noconfirm
            cd ..
        fi

        yay -S --noconfirm $(cat "$aurPackages")

        if [ "$(ls | grep -o -m 1 "castle-shell")" = "castle-shell" ];
        then 
            sudo -S rm -r ./castle-shell/
        fi
        git clone https://github.com/KCkingcollin/castle-shell
        cd castle-shell/color-checker || return
        sudo -S go build -o /usr/bin/color-checker
        cd ../..

        sudo -S flatpak remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
        sudo -S flatpak override --filesystem="/home/$userName"/.themes
        sudo -S flatpak override --filesystem="/home/$userName"/.icons
        sudo -S flatpak override --filesystem="/home/$userName"/.gtkrc-2.0
        sudo -S flatpak override --env=GTK_THEME=Adwaita-dark
        sudo -S flatpak override --env=ICON_THEME=Adwaita-dark
    }
    sudo -S -i -u "$userName" $(commands)
}

function configSetup {
    userName=$1
    function commands {
        cd "/home/$userName" || return
        cloneRepo

        mv "$userName/.config/nvim" "$userName/.config/nvim.bac" 
        mv "$userName/.config/fastfetch" "$userName/.config/fastfetch.bac" 
        mv "$userName/.config/kitty" "$userName/.config/foot.bac" 
        mv "$userName/.config/hypr" "$userName/.config/hypr.bac" 
        mv "$userName/.config/waybar" "$userName/.config/waybar.bac" 
        mv "$userName/.config/swaync" "$userName/.config/swaync.bac" 
        mv "$userName/.config/rofi" "$userName/.config/rofi.bac" 
        mv "$userName/.config/castle-shell" "$userName/.config/castle-shell.bac" 
        mv "$userName/.zshrc" "$userName/.zshrc.bac" 
        mv "$userName/.themes" "$userName/.themes.bac" 
        mv "$userName/.icons" "$userName/.icons.bac" 
        mv "$userName/.gtkrc-2.0" "$userName/.gtkrc-2.0.bac" 

        mkdir "$userName"/.config
        yes | cp -rf config/* "$userName/.config/"
        sudo -S cp -rf config/* "/root/.config/"
        yes | cp -rf ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 "$userName/"
        sudo -S cp -rf ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 "/root/"
        sudo -S cp -rf etc/* /etc/
        sudo -S cp -rf ./switch-DEs.sh /usr/bin/switch-DEs
        sudo -S cp -rf ./theme-check.service ./waybar-hyprland.service /usr/lib/systemd/user/
        sudo -S cp -rf ./switch-DEs.service  /etc/systemd/system/
        yes | cp -rf ./after.sh /"$userName"/.config/hypr/
        mv /"$userName"/.config/hypr/hyprland.conf /"$userName"/.config/hypr/hyprland.conf.bac
        yes | cp -rf ./hyprland.conf.once /"$userName"/.config/hypr/hyprland.conf
        sudo -S chsh -s /bin/zsh "$userName"
        sudo -S chsh -s /bin/zsh root

        if [ "$(ls "$userName/Pictures/" | grep -o -m 1 "background.jpg")" != "background.jpg" ];
        then
            mkdir -p "$userName/Pictures" 
            yes | cp ./background.jpg "$userName/Pictures/background.jpg"
        fi

        sudo -S rate-mirrors --allow-root --save /etc/pacman.d/mirrorlist arch

        nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

        sudo -S bash -c echo '[User]                        
Session=hyprland
XSession=hyprland
Icon="$userName"/.face
SystemAccount=false' > /var/lib/AccountsService/users/"$userName"
    }
    sudo -S -i -u "$userName" $(commands)
}

function main {
    if [[ $(id -u) = 0 ]]; then
        echo "Clean install arch?"
        read -rp "[Y/n]: " answer
        if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]; then
            cloneRepo
            cp -rf etc/* /etc/
            pacman -Syy --noconfirm archlinux-keyring arch-install-scripts
            echo "Install dir?"
            read -rp " > " rootdir
            cd "$rootdir" || return
            rootdir="$(pwd)"
            cd - || return
            pacstrap -K "$rootdir" $(cat "$archPackages")
            export -f chrootSetup extraPackages configSetup
            username="$(arch-chroot "$rootdir" /bin/bash -c chrootSetup | tail -n 1)"
            arch-chroot "$rootdir" /bin/bash -c extraPackages "$username"
            arch-chroot "$rootdir" /bin/bash -c configSetup "$username"
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
