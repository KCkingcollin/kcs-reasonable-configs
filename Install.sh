#!/bin/bash

if [ $USER = 'root' ]
then
    pacman -Syyu --noconfirm sudo hyprland hyprpaper waybar swaync playerctl polkit-gnome gnome-keyring pipewire wireplumber xdg-desktop-portal-hyprland otf-geist-mono-nerd otf-font-awesome pavucontrol nm-connection-editor networkmanager blueman git base-devel flatpak nemo rofi-wayland neovim foot gdm cpio meson cmake zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search neofetch kdeconnect npm gtk2 gtk3 gtk4 hyprwayland-scanner
    echo "You need to run this script as a sudo user NOT as root"
    echo "Create a new account?"
    read -p "[Y/n]: " answer
    if [ "$(echo "$answer" | grep -o -m 1 "y")" = "y" ]
    then
        read -p "Name of the account?: " accountName
        useradd -m $accountName
        passwd $accountName
        groupadd sudo
        usermod -aG sudo $accountName
        if [ "$(cat /etc/sudoers | grep -o -m 1 "# %sudo")" = "# %sudo" ]
        then
            echo "%sudo	ALL=(ALL:ALL) ALL" > /etc/sudoers.d/sudo-enable 
        fi
        cd "/home/$accountName"
        sudo -S -i -u $accountName git clone https://github.com/KCkingcollin/kcs-reasonable-configs
        cd "/home/$accountName/kcs-reasonable-configs"
        su -c "./Install.sh" $accountName
        return
    else
        read -p "Username?: " accountName
        groupadd sudo
        usermod -aG sudo $accountName
        if [ "$(cat /etc/sudoers | grep -o -m 1 "# %sudo")" = "# %sudo" ]
        then
            echo "%sudo	ALL=(ALL:ALL) ALL" > /etc/sudoers.d/sudo-enable 
        fi
        cd "/home/$accountName"
        sudo -S -i -u $accountName git clone https://github.com/KCkingcollin/kcs-reasonable-configs
        cd "/home/$accountName/kcs-reasonable-configs"
        su $accountName
        su -c "./Install.sh" $accountName
        return
    fi
else
    sudo -S pacman -Syyu --noconfirm sudo hyprland hyprpaper waybar swaync playerctl polkit-gnome gnome-keyring pipewire wireplumber xdg-desktop-portal-hyprland otf-geist-mono-nerd otf-font-awesome pavucontrol nm-connection-editor networkmanager blueman git base-devel flatpak nemo rofi-wayland neovim foot gdm cpio meson cmake zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search neofetch kdeconnect npm gtk2 gtk3 gtk4 hyprwayland-scanner
fi

if [ "$(pacman -Q | grep -o -m 1 yay)" != "yay" ];
then
    if [ "$(ls | grep -o -m 1 "yay")" = "yay" ];
    then 
        sudo -S rm -r ./yay/
    fi
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
fi

# yay -S --noconfirm hyprshot nvim-packer-git hy3-git oh-my-zsh-git hyprland-git hyprland-plugin-hyprbars-git nwg-shell
yay -S --noconfirm hyprshot nvim-packer-git oh-my-zsh-git nwg-shell pamac-all

sudo -S flatpak -y remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
sudo -S flatpak -y install org.mozilla.firefox/x86_64/stable
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
    git clone https://github.com/KCkingcollin/kcs-reasonable-configs
    cd kcs-reasonable-configs
fi
mv "$HOME/.config/nvim" "$HOME/.config/nvim.bac" 
mv "$HOME/.config/foot" "$HOME/.config/foot.bac" 
mv "$HOME/.config/hypr" "$HOME/.config/hypr.bac" 
mv "$HOME/.config/waybar" "$HOME/.config/waybar.bac" 
mv "$HOME/.config/swaync" "$HOME/.config/swaync.bac" 
mv "$HOME/.config/rofi" "$HOME/.config/rofi.bac" 
mv "$HOME/.config/castle-shell" "$HOME/.config/castle-shell.bac" 
mv "$HOME/.zshrc" "$HOME/.zshrc.bac" 
mv "$HOME/.themes" "$HOME/.themes.bac" 
mv "$HOME/.icons" "$HOME/.icons.bac" 
mv "$HOME/.gtkrc-2.0" "$HOME/.gtkrc-2.0.bac" 

location="$(pwd)"

mkdir $HOME/.config

yes | cp -rf "$location"/nvim "$location"/foot "$location"/hypr "$location"/waybar "$location"/swaync "$location"/rofi "$location"/castle-shell "$HOME/.config/"

yes | cp -rf "$location"/.zshrc "$location"/.themes "$location"/.icons "$location"/.gtkrc-2.0 "$HOME/"

sudo -S cp -rf "$location"/switch-DEs.sh /usr/bin/

sudo -S cp -rf "$location"/switch-DEs.service /etc/systemd/system/

yes | cp -rf "$location"/after.sh /"$HOME"/.config/hypr/

mv /"$HOME"/.config/hypr/hyprland.conf /"$HOME"/.config/hypr/hyprland.conf.bac

yes | cp -rf "$location"/hyprland.conf.once /"$HOME"/.config/hypr/hyprland.conf

sudo -S chsh -s /bin/zsh $USER

if [ "$(ls "$HOME/Pictures/" | grep -o -m 1 "background.jpg")" != "background.jpg" ];
then
    mkdir -p "$HOME/Pictures" 
    cp ./background.jpg "$HOME/Pictures/background.jpg"
fi

nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

sudo -S systemctl start switch-DEs.service
