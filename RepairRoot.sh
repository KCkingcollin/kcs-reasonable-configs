#!/bin/bash

function chrootInstall {
    systemctl enable NetworkManager
    systemctl enable gdm
    grub-install --target=x86_64-efi --efi-directory=boot --bootloader-id=GRUB
    grub-mkconfig -o /boot/grub/grub.cfg

    read -rp "Name of the account?: " accountName
    sudo -S -i -u "$accountName" "$(
        git clone https://aur.archlinux.org/yay.git
        cd yay || return
        makepkg -si --noconfirm
        cd ..
        yay -S --noconfirm hyprshot nvim-packer-git oh-my-zsh-git nwg-displays pamac-all

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

        # make damn sure it gets the environment before running hyprland the first time
        systemctl --user import-environment
    )"
    echo "Done"
}

export -f chrootInstall

if [ "$USER" = 'root' ]; then
    # checking to make sure we are not in chroot
    echo "root dir?"
    read -rp " > " rootdir
    if ! [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ]; then
        mkdir oldfiles
        mkdir oldfiles/etc
        cd "$rootdir"/etc || return
        if ! cp -R fstab passwd shadow default group* cron* local* NetworkManager pacman* sudo* ssh* ssl* hostname ../../oldfiles/etc/; then
            echo "couldn't copy some files, not attempting the whipe"
            return
        fi
        cd ..
        echo "About to whipe root and reintall, contenue?"
        read -rp "[Y/n]: " answer
        if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ] then
            for file in *; do
                if [[ "$file" != *"home"* || "$file" != *"root"* || "$file" != *"dev"* ]]; then 
                    rm -r "$file"
                fi
            done
        fi
        cd ../oldfiles || return
        if ! cp -R etc ../"$rootdir"/; then
            echo "couldn't copy some files, not attempting to install"
            return
        fi
        cd ..
        pacstrap -K "$rootdir" linux-lts arch-install-scripts os-prober efibootmgr linux-firmware linux-lts-headers grub sudo hyprland hyprpaper waybar swaync playerctl polkit-gnome gnome-keyring pipewire wireplumber xdg-desktop-portal-hyprland otf-geist-mono-nerd otf-font-awesome pavucontrol nm-connection-editor networkmanager blueman git base-devel flatpak nemo rofi-wayland neovim kitty gdm cpio meson cmake zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search fastfetch kdeconnect npm gtk2 gtk3 gtk4 hyprwayland-scanner gnome-control-center python xdg-desktop-portal xdg-desktop-portal-gtk xdg-user-dirs firefox go wget
        arch-chroot "$rootdir" /bin/bash -c chrootInstall
    else
        chrootInstall
    fi
else
    echo "not root"
fi
