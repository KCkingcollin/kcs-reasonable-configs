#!/bin/bash

function cloneRepo {
    if ! grep -q "kcs-reasonable-configs" <(pwd) <(ls); then
        git clone https://github.com/KCkingcollin/kcs-reasonable-configs
    fi
    if [ -d "kcs-reasonable-configs" ]; then
        cd kcs-reasonable-configs || return
    fi
    repoLocation="$(pwd)"
    archPackages="$repoLocation/arch-packages"
    aurPackages="$repoLocation/aur-packages"
}

function createAccount {
    printf "Name of the account?: "
    read -r userName
    printf '\n'
    useradd -m "$userName"
    passwd "$userName"
    addUserToSudo "$userName"
}

function getAccount {
    echo "Provid the account usernemae you want to set the environment up with"
    printf "Username?: "
    read -r userName
    printf '\n'
    addUserToSudo "$userName"
}

function addUserToSudo {
    userName=$1
    groupadd sudo
    usermod -aG sudo "$userName"
    sed -i 's/^#%sudo/%sudo/' /etc/sudoers
    echo "$userName"
}

function createSudoUser {
    echo "$userName ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/temp_rule
}

function removeSudoUser {
    rm /etc/sudoers.d/temp_rule
}

function checkAndFixFstab {
    if [ "$#" -lt 1 ]; then
        echo "No devices given."
        return 1
    fi
    for elm in range "$@"; do
        sed -i "/^#/! s|$elm|UUID=$(blkid | grep "$elm" | cut -d'"' -f2)|" /etc/fstab
    done
}

function chrootSetup {
    genfstab -U / >> /etc/fstab
    checkAndFixFstab "$@" || return 1
    timedatectl set-ntp true
    hwclock --systohc
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    echo "KEYMAP=us" > /etc/vconsole.conf
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen
    locale-gen
    echo "Set the root password"
    passwd
    systemctl enable NetworkManager
    systemctl enable gdm
    systemctl enable cronie
    pacman -Syyu --noconfirm
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARCH
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck
    grub-mkconfig -o /boot/grub/grub.cfg
    createAccount
}

function extraPackages {
    createSudoUser
    homeDir=$(getent passwd "$userName" | cut -d: -f6)
    cd "$homeDir" || return
    mv "$repoLocation" "$homeDir/kcs-reasonable-configs" &> /dev/null
    cloneRepo
    chown -R "$userName":"$userName" "$homeDir"

    if ! pacman -Q | grep -q "yay"; then
        if [ ! -d "yay-bin" ]; then 
            git clone https://aur.archlinux.org/yay-bin.git
        fi
        cd yay-bin || return
        chown -R "$userName":"$userName" .
        sudo -S -u "$userName" makepkg -si --noconfirm
        cd ..
    fi

    sudo -S -u "$userName" yay -Sy --noconfirm $(cat "$aurPackages")

    if [ -d "castle-shell" ]; then 
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
    removeSudoUser
}

function configSetup {
    createSudoUser
    homeDir=$(getent passwd "$userName" | cut -d: -f6)
    cd "$homeDir" || return
    mv "$repoLocation" "$homeDir/kcs-reasonable-configs" &> /dev/null
    cloneRepo
    chown -R "$userName":"$userName" .

    mv "$homeDir"/.config/nvim "$homeDir"/.config/nvim.bac &> /dev/null
    mv "$homeDir"/.config/fastfetch "$homeDir"/.config/fastfetch.bac &> /dev/null
    mv "$homeDir"/.config/kitty "$homeDir"/.config/foot.bac &> /dev/null
    mv "$homeDir"/.config/hypr "$homeDir"/.config/hypr.bac &> /dev/null
    mv "$homeDir"/.config/waybar "$homeDir"/.config/waybar.bac &> /dev/null
    mv "$homeDir"/.config/swaync "$homeDir"/.config/swaync.bac &> /dev/null
    mv "$homeDir"/.config/rofi "$homeDir"/.config/rofi.bac &> /dev/null
    mv "$homeDir"/.config/castle-shell "$homeDir"/.config/castle-shell.bac &> /dev/null
    mv "$homeDir"/.zshrc "$homeDir"/.zshrc.bac &> /dev/null
    mv "$homeDir"/.themes "$homeDir"/.themes.bac &> /dev/null
    mv "$homeDir"/.icons "$homeDir"/.icons.bac &> /dev/null
    mv "$homeDir"/.gtkrc-2.0 "$homeDir"/.gtkrc-2.0.bac &> /dev/null

    mv /root/.config/nvim /root/.config/nvim.bac &> /dev/null
    mv /root/.config/fastfetch /root/.config/fastfetch.bac &> /dev/null
    mv /root/.config/kitty /root/.config/foot.bac &> /dev/null
    mv /root/.config/hypr /root/.config/hypr.bac &> /dev/null
    mv /root/.config/waybar /root/.config/waybar.bac &> /dev/null
    mv /root/.config/swaync /root/.config/swaync.bac &> /dev/null
    mv /root/.config/rofi /root/.config/rofi.bac &> /dev/null
    mv /root/.config/castle-shell /root/.config/castle-shell.bac &> /dev/null
    mv /root/.zshrc /root/.zshrc.bac &> /dev/null
    mv /root/.themes /root/.themes.bac &> /dev/null
    mv /root/.icons /root/.icons.bac &> /dev/null
    mv /root/.gtkrc-2.0 /root/.gtkrc-2.0.bac &> /dev/null

    sudo -S -u "$userName" mkdir "$homeDir"/.config &> /dev/null
    cp -rfp config/* "$homeDir"/.config/
    mv "$homeDir"/.config/nvim/lua/user "$homeDir"/.config/nvim/lua/"$userName"
    cp -rfp ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 "$homeDir"/
    cp -rfp ./after.sh "$homeDir"/.config/hypr/
    mv "$homeDir"/.config/hypr/hyprland.conf "$homeDir"/.config/hypr/hyprland.conf.bac
    cp -rfp ./hyprland.conf.once "$homeDir"/.config/hypr/hyprland.conf

    mkdir /root/.config &> /dev/null
    cp -rf config/* /root/.config/
    cp -rf etc/* /etc/
    mv /root/.config/nvim/lua/user /root/.config/nvim/lua/root
    cp -rf ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 /root/
    cp -rf ./switch-DEs.sh /usr/bin/switch-DEs
    cp -rf ./theme-check.service ./waybar-hyprland.service /usr/lib/systemd/user/
    cp -rf ./switch-DEs.service  /etc/systemd/system/
    mkdir -p /root/.local/share/nvim
    mkdir -p /root/.local/state/nvim
    chown -R root:root /root/

    chsh -s /bin/zsh "$userName"
    chsh -s /bin/zsh root

    if [ ! -d "$homeDir/Pictures/background.jpg" ];
    then
        sudo -S -u "$userName" mkdir -p "$homeDir"/Pictures &> /dev/null
        cp -fp ./background.jpg "$homeDir"/Pictures/background.jpg
    fi

    sudo -S -u "$userName" gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
    sudo -S -u "$userName" gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

    rate-mirrors --allow-root --save /etc/pacman.d/mirrorlist arch

    sudo -S -u "$userName" nvim --headless -c 'lua vim.cmd("PackerSync")' -c 'autocmd User PackerComplete quitall'
    nvim --headless -c 'lua vim.cmd("PackerSync")' -c 'autocmd User PackerComplete quitall'

    bash -c echo '[User]                        
    Session=hyprland
    XSession=hyprland
    Icon="$userName"/.face
    SystemAccount=false' > /var/lib/AccountsService/users/"$userName"
    removeSudoUser
}

function main {
    # check to see if the user is root
    if [[ $(id -u) = 0 ]]; then
        echo "Clean install arch?"
        read -rp "[Y/n]: " cleanInstall
        if [[ "$cleanInstall" =~ ^[yY]([eE][sS])?$ ]]; then
            cloneRepo
            echo "Replace repos with arch repos?"
            read -rp "[Y/n]: " replaceRepos
            if [[ "$replaceRepos" =~ ^[yY]([eE][sS])?$ ]]; then
                cp -rf etc/* /etc/
            elif [[ -z "$replaceRepos" ]]; then
                echo "no input"
                return
            fi
            cd /
            pacman -Syy --noconfirm archlinux-keyring arch-install-scripts
            lsblk

            echo "Auto mount partitions?"
            read -rp "[Y/n]: " autoMount
            if [[ "$autoMount" =~ ^[yY]([eE][sS])?$ ]]; then
                echo "Boot partition?"
                read -rp " > " partBoot
                echo "Root partition (needs to be btrfs)?"
                read -rp " > " partRoot
                echo "Home partition (leave blank to use the same partition)?"
                read -rp " > " partHome
                echo "Swap partition?"
                read -rp " > " partSwap

                if [[ -z "$partRoot" ]]; then
                    echo "No root provided, stopping installation"
                    return
                else
                    mount "$partRoot" /mnt || exit
                    cd /mnt || exit
                    btrfs subvolume create @ || exit
                fi

                if [[ -z "$partHome" ]]; then
                    btrfs subvolume create @home
                    cd /
                    umount /mnt
                    mount -t btrfs -o subvol=@ "$partRoot" /mnt || exit
                    mkdir /mnt/home 
                    mount -t btrfs -o subvol=@home "$partRoot" /mnt/home || exit
                else
                    cd /
                    umount /mnt
                    mount -t btrfs -o subvol=@ "$partRoot" /mnt || exit
                    mkdir /mnt/home
                    mount "$partHome" /mnt/home || exit
                fi

                mkdir -p /mnt/boot/efi
                if [[ -z "$partBoot" ]]; then
                    echo "Bios boot is not supported, need a fat32 efi partition"
                    return
                else
                    mount "$partBoot" /mnt/boot/efi || exit
                fi

                if [[ -z "$partSwap" ]]; then
                    echo "Swap file not yet supported, continuing without swap"
                    swapoff -a
                else
                    swapoff -a
                    swapon "$partSwap"
                fi
            elif [[ -z "$autoMount" ]]; then
                echo "no input"
                return
            fi

            pacstrap -c /mnt $(cat "$archPackages") || exit
            mkdir /mnt/kcs-reasonable-configs
            cp -r "$repoLocation"/* "$repoLocation"/.* /mnt/kcs-reasonable-configs/
            repoLocation="/kcs-reasonable-configs"
            export -f chrootSetup extraPackages configSetup cloneRepo getAccount createAccount addUserToSudo createSudoUser removeSudoUser checkAndFixFstab || exit
            export userName repoLocation || exit
            output=$(arch-chroot /mnt bash -c 'chrootSetup "$@"' _ "$partRoot" "$partBoot" "$partSwap" "$partHome")
            if [ $? -ne 0 ]; then
                echo "Error: chrootSetup failed."
                exit 1
            fi
            userName=$(echo "$output" | tail -n 1)
            read -rp "Name of the machine?: " hostName
            if [[ -z "$hostName" ]]; then
                echo "no input"
                return
            fi
            echo "$hostName" > /mnt/etc/hostname
            mkdir -p /mnt/home/"$userName"/.cache/yay
            cp -r /home/*/.cache/yay/* /mnt/home/"$userName"/.cache/yay/
            arch-chroot /mnt /bin/bash -c extraPackages
            arch-chroot /mnt /bin/bash -c configSetup

            swapoff -a
            umount -l /mnt
            return
        elif [[ -z "$cleanInstall" ]]; then
            echo "no input"
            return
        fi
        cloneRepo
        echo "Replace repos with arch repos?"
        read -rp "[Y/n]: " replaceRepos
        if [[ "$replaceRepos" =~ ^[yY]([eE][sS])?$ ]]; then
            cp -rf etc/* /etc/
        elif [[ -z "$replaceRepos" ]]; then
            echo "no input"
            return
        fi
        pacman -Syy --noconfirm archlinux-keyring
        pacman -Syyu --noconfirm --nodeps $(cat "$archPackages")
        if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
            partRoot="$(df --output=source,target | grep "/" | head -n 1 | awk '{print $1}')"
            partBoot="$(df --output=source,target | grep "/boot" | head -n 1 | awk '{print $1}')"
            partHome="$(df --output=source,target | grep "/home" | head -n 1 | awk '{print $1}')"

            userName="$(chrootSetup "$partRoot" "$partBoot" "$partHome" | tail -n 1)"

            extraPackages
            configSetup
            return
        else
            echo "Create a new account?"
            read -rp "[Y/n]: " createAccount
            if [[ "$createAccount" =~ ^[yY]([eE][sS])?$ ]]; then
                userName="$(createAccount | tail -n 1)"
            else
                userName="$(getAccount | tail -n 1)"
            fi
            if [[ -z "$userName" ]]; then
                echo "no input"
                return
            fi
            homeDir=$(getent passwd "$userName" | cut -d: -f6)
            mkdir -p /home/"$homeDir"/.cache/yay
            cp -r /home/*/.cache/yay/* /home/"$homeDir"/.cache/yay/
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
    main 
fi
