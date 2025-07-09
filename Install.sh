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

    sudo -S -i -u "$accountName" "$(
        git clone https://aur.archlinux.org/yay.git
        cd yay || return
        makepkg -si --noconfirm
        cd ..
        yay -S --noconfirm hyprshot nvim-packer-git oh-my-zsh-git nwg-displays pamac-all

        git clone https://github.com/KCkingcollin/kcs-reasonable-configs
        cd "kcs-reasonable-configs" || return

        git clone https://github.com/KCkingcollin/castle-shell
        cd castle-shell/color-checker || return
        sudo -S go build -o /usr/bin/color-checker
        cd ../..

        sudo -S flatpak -y remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
        sudo -S flatpak override --filesystem="$accountName"/.themes
        sudo -S flatpak override --filesystem="$accountName"/.icons
        sudo -S flatpak override --filesystem="$accountName"/.gtkrc-2.0
        sudo -S flatpak override --env=GTK_THEME=Adwaita-dark
        sudo -S flatpak override --env=ICON_THEME=Adwaita-dark

        mv "$accountName/.config/nvim" "$accountName/.config/nvim.bac" 
        mv "$accountName/.config/fastfetch" "$accountName/.config/fastfetch.bac" 
        mv "$accountName/.config/kitty" "$accountName/.config/foot.bac" 
        mv "$accountName/.config/hypr" "$accountName/.config/hypr.bac" 
        mv "$accountName/.config/waybar" "$accountName/.config/waybar.bac" 
        mv "$accountName/.config/swaync" "$accountName/.config/swaync.bac" 
        mv "$accountName/.config/rofi" "$accountName/.config/rofi.bac" 
        mv "$accountName/.config/castle-shell" "$accountName/.config/castle-shell.bac" 
        mv "$accountName/.zshrc" "$accountName/.zshrc.bac" 
        mv "$accountName/.themes" "$accountName/.themes.bac" 
        mv "$accountName/.icons" "$accountName/.icons.bac" 
        mv "$accountName/.gtkrc-2.0" "$accountName/.gtkrc-2.0.bac" 

        mkdir "$accountName"/.config

        yes | cp -rf ./nvim ./kitty ./hypr ./waybar ./swaync ./rofi ./castle-shell ./fastfetch "$accountName/.config/"

        yes | cp -rf ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 "$accountName/"

        sudo -S cp -rf ./switch-DEs.sh /usr/bin/switch-DEs

        sudo -S cp -rf ./theme-check.service ./waybar-hyprland.service /usr/lib/systemd/user/

        sudo -S cp -rf ./switch-DEs.service  /etc/systemd/system/

        yes | cp -rf ./after.sh /"$accountName"/.config/hypr/

        mv /"$accountName"/.config/hypr/hyprland.conf /"$accountName"/.config/hypr/hyprland.conf.bac

        yes | cp -rf ./hyprland.conf.once /"$accountName"/.config/hypr/hyprland.conf

        sudo -S chsh -s /bin/zsh "$USER"

        mkdir -p "$accountName/Pictures" 
        cp ./background.jpg "$accountName/Pictures/background.jpg"

        nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

        # make damn sure it gets the environment before running hyprland the first time
        systemctl --user import-environment
    )"

    echo "[User]
Session=hyprland
XSession=hyprland
Icon=$accountName/.face
SystemAccount=false" > /var/lib/AccountsService/users/"$accountName"
    echo "Done"
    echo "Reboot into the new drive"
}

export -f chrootInstall

if [ "$USER" = 'root' ]
then
    echo "Installing?"
    read -rp "[Y/n]: " answer
    if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ] then
        echo "Install dir?"
        read -rp " > " answer
        pacstrap -K "$answer" linux-lts arch-install-scripts os-prober efibootmgr linux-firmware linux-lts-headers grub sudo hyprland hyprpaper waybar swaync playerctl polkit-gnome gnome-keyring pipewire wireplumber xdg-desktop-portal-hyprland otf-geist-mono-nerd otf-font-awesome pavucontrol nm-connection-editor networkmanager blueman git base-devel flatpak nemo rofi-wayland neovim kitty gdm cpio meson cmake zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search fastfetch kdeconnect npm gtk2 gtk3 gtk4 hyprwayland-scanner gnome-control-center python xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs firefox go wget
        arch-chroot "$answer" /bin/bash -c chrootInstall
        return
    fi
    echo "In a chroot?"
    read -rp "[Y/n]: " answer
    if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]
    then
        chrootInstall
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

sudo -S flatpak -y remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
sudo -S flatpak override --filesystem="$HOME"/.themes
sudo -S flatpak override --filesystem="$HOME"/.icons
sudo -S flatpak override --filesystem="$HOME"/.gtkrc-2.0
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
mv "$HOME/.config/nvim" "$HOME/.config/nvim.bac" 
mv "$HOME/.config/fastfetch" "$HOME/.config/fastfetch.bac" 
mv "$HOME/.config/kitty" "$HOME/.config/foot.bac" 
mv "$HOME/.config/hypr" "$HOME/.config/hypr.bac" 
mv "$HOME/.config/waybar" "$HOME/.config/waybar.bac" 
mv "$HOME/.config/swaync" "$HOME/.config/swaync.bac" 
mv "$HOME/.config/rofi" "$HOME/.config/rofi.bac" 
mv "$HOME/.config/castle-shell" "$HOME/.config/castle-shell.bac" 
mv "$HOME/.zshrc" "$HOME/.zshrc.bac" 
mv "$HOME/.themes" "$HOME/.themes.bac" 
mv "$HOME/.icons" "$HOME/.icons.bac" 
mv "$HOME/.gtkrc-2.0" "$HOME/.gtkrc-2.0.bac" 

mkdir "$HOME"/.config

yes | cp -rf ./nvim ./kitty ./hypr ./waybar ./swaync ./rofi ./castle-shell ./fastfetch "$HOME/.config/"

yes | cp -rf ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 "$HOME/"

sudo -S cp -rf ./switch-DEs.sh /usr/bin/switch-DEs

sudo -S cp -rf ./theme-check.service ./waybar-hyprland.service /usr/lib/systemd/user/

sudo -S cp -rf ./switch-DEs.service  /etc/systemd/system/

yes | cp -rf ./after.sh /"$HOME"/.config/hypr/

mv /"$HOME"/.config/hypr/hyprland.conf /"$HOME"/.config/hypr/hyprland.conf.bac

yes | cp -rf ./hyprland.conf.once /"$HOME"/.config/hypr/hyprland.conf

sudo -S chsh -s /bin/zsh "$USER"

if [ "$(ls "$HOME/Pictures/" | grep -o -m 1 "background.jpg")" != "background.jpg" ];
then
    mkdir -p "$HOME/Pictures" 
    cp ./background.jpg "$HOME/Pictures/background.jpg"
fi

nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

# make damn sure it gets the environment before running hyprland the first time
systemctl --user import-environment

sudo -S bash -c 'echo "[User]                        
Session=hyprland
XSession=hyprland
Icon="$HOME"/.face
SystemAccount=false" > /var/lib/AccountsService/users/"$USER"'

sudo -S systemctl start switch-DEs.service
