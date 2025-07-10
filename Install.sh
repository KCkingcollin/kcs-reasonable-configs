#!/bin/bash

function chrootInstall {
    echo "Set the root password"
    passwd
    systemctl enable NetworkManager
    systemctl enable gdm
    grub-install --target=x86_64-efi --efi-directory=boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg
    genfstab -U / >> /etc/fstab
    read -rp "Name of the account?: " accountName
    useradd -m "$accountName"
    passwd "$accountName"
    groupadd sudo
    usermod -aG sudo "$accountName"
    echo "%sudo	ALL=(ALL:ALL) ALL" > /etc/sudoers.d/sudo-enable 
    echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" > /etc/pacman.conf
    cd "/home/$accountName" || return
    sudo -S -i -u "$accountName" "$(configSetup "$accountName")"
    echo "Done"
    echo "Reboot into the new drive"
}

function configSetup {
    userName=$1
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

    yay -S --noconfirm hyprshot nvim-packer-git oh-my-zsh-git nwg-displays pamac-all

    if [ "$(ls | grep -o -m 1 "castle-shell")" = "castle-shell" ];
    then 
        sudo -S rm -r ./castle-shell/
    fi
    git clone https://github.com/KCkingcollin/castle-shell
    cd castle-shell/color-checker || return
    sudo -S go build -o /usr/bin/color-checker
    cd ../..

    sudo -S flatpak remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
    sudo -S flatpak override --filesystem="$userName"/.themes
    sudo -S flatpak override --filesystem="$userName"/.icons
    sudo -S flatpak override --filesystem="$userName"/.gtkrc-2.0
    sudo -S flatpak override --env=GTK_THEME=Adwaita-dark
    sudo -S flatpak override --env=ICON_THEME=Adwaita-dark

    if [ "$(git status | grep -o -m 1 "On branch main")" != "On branch main" ]
    then
        if [ "$(ls | grep -o -m 1 "kcs-reasonable-configs")" = "kcs-reasonable-configs" ];
        then 
            sudo -S rm -r ./kcs-reasonable-configs/
        fi
        git clone https://github.com/KCkingcollin/kcs-reasonable-config
        cd kcs-reasonable-configs || return
    fi
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

    yes | cp -rf ./nvim ./kitty ./hypr ./waybar ./swaync ./rofi ./castle-shell ./fastfetch "$userName/.config/"

    yes | cp -rf ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 "$userName/"

    yes | cp -rf pacman* /etc/

    sudo -S cp -rf ./switch-DEs.sh /usr/bin/switch-DEs

    sudo -S cp -rf ./theme-check.service ./waybar-hyprland.service /usr/lib/systemd/user/

    sudo -S cp -rf ./switch-DEs.service  /etc/systemd/system/

    yes | cp -rf ./after.sh /"$userName"/.config/hypr/

    mv /"$userName"/.config/hypr/hyprland.conf /"$userName"/.config/hypr/hyprland.conf.bac

    yes | cp -rf ./hyprland.conf.once /"$userName"/.config/hypr/hyprland.conf

    sudo -S chsh -s /bin/zsh "$userName"

    if [ "$(ls "$userName/Pictures/" | grep -o -m 1 "background.jpg")" != "background.jpg" ];
    then
        mkdir -p "$userName/Pictures" 
        cp ./background.jpg "$userName/Pictures/background.jpg"
    fi

    nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

    sudo -S bash -c echo '[User]                        
Session=hyprland
XSession=hyprland
Icon="$userName"/.face
SystemAccount=false' > /var/lib/AccountsService/users/"$userName"
}

export -f chrootInstall
export -f configSetup

if [ "$USER" = 'root' ]
then
    echo "Installing?"
    read -rp "[Y/n]: " answer
    if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ] then
        echo "Install dir?"
        read -rp " > " answer
        (
            git clone https://github.com/KCkingcollin/kcs-reasonable-config
            cd kcs-reasonable-configs || return
            yes | cp -rf pacman* /etc/
        )
        pacstrap -K "$answer" linux-lts arch-install-scripts os-prober efibootmgr linux-firmware linux-lts-headers grub sudo hyprland hyprpaper waybar swaync playerctl polkit-gnome gnome-keyring pipewire wireplumber xdg-desktop-portal-hyprland otf-geist-mono-nerd otf-font-awesome pavucontrol nm-connection-editor networkmanager blueman git base-devel flatpak nemo rofi-wayland neovim kitty gdm cpio meson cmake zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search fastfetch kdeconnect npm gtk2 gtk3 gtk4 hyprwayland-scanner gnome-control-center python xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs firefox go wget
        arch-chroot "$answer" /bin/bash -c chrootInstall
        return
    fi
    echo "In a chroot?"
    read -rp "[Y/n]: " answer
    if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]
    then
        "$(chrootInstall)"
        return
    else
        echo "Create a new account?"
        read -rp "[Y/n]: " answer
        if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]
        then
            read -rp "Name of the account?: " accountName
            useradd -m "$accountName"
            passwd "$accountName"
            groupadd sudo
            usermod -aG sudo "$accountName"
            if [ "$(grep -o -m 1 "# %sudo" < /etc/sudoers)" = "# %sudo" ]
            then
                echo "%sudo	ALL=(ALL:ALL) ALL" > /etc/sudoers.d/sudo-enable 
            fi
            if [ "$(grep -o -m 1 "# [multilib]" < /etc/sudoers)" = "# [multilib]" ]
            then
                echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" > /etc/pacman.conf
            fi
            cd "/home/$accountName" || return
            sudo -S -i -u "$accountName" git clone https://github.com/KCkingcollin/kcs-reasonable-configs
            cd "/home/$accountName/kcs-reasonable-configs" || return
            su -c "./Install.sh" "$accountName"
            return
        else
            echo "Provid the account usernemae you want to set the environment up with"
            read -rp "Username?: " accountName
            groupadd sudo
            usermod -aG sudo "$accountName"
            if [ "$(grep -o -m 1 "# %sudo" < /etc/sudoers)" = "# %sudo" ]
            then
                echo "%sudo	ALL=(ALL:ALL) ALL" > /etc/sudoers.d/sudo-enable 
            fi
            if [ "$(grep -o -m 1 "# [multilib]" < /etc/sudoers)" = "# [multilib]" ]
            then
                echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" > /etc/pacman.conf
            fi
            cd "/home/$accountName" || return
            sudo -S -i -u "$accountName" git clone https://github.com/KCkingcollin/kcs-reasonable-configs
            cd "/home/$accountName/kcs-reasonable-configs" || return
            su -c "./Install.sh" "$accountName"
            return
        fi
    fi
else
    sudo -S pacman -Syyu --noconfirm sudo hyprland hyprpaper waybar swaync playerctl polkit-gnome gnome-keyring pipewire wireplumber xdg-desktop-portal-hyprland otf-geist-mono-nerd otf-font-awesome pavucontrol nm-connection-editor networkmanager blueman git base-devel flatpak nemo rofi-wayland neovim kitty gdm cpio meson cmake zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search fastfetch kdeconnect npm gtk2 gtk3 gtk4 hyprwayland-scanner gnome-control-center python xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs firefox go
fi

"$(configSetup "$USER")"

# make damn sure it gets the environment before running hyprland the first time
systemctl --user import-environment

sudo -S systemctl start switch-DEs.service

