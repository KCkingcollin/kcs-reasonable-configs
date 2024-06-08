#!/bin/bash

if [ $USER = 'root' ]
then
    pacman -Syyu --noconfirm sudo hyprpaper waybar swaync playerctl polkit-gnome gnome-keyring pipewire wireplumber xdg-desktop-portal-hyprland otf-geist-mono-nerd otf-font-awesome pavucontrol nm-connection-editor networkmanager blueman git base-devel flatpak nemo rofi-wayland neovim foot gdm cpio meson cmake zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search neofetch kdeconnect npm gtk2 gtk3 gtk4
    echo "You need to run this script as a user with sudo NOT as root"
    echo "Create a new account?"
    read -p "[Y/n]: " answer
    if [ "$(echo "$answer" | grep -o "y")" = "y" ]
    then
        read -p "Name of the account?: " accountName
        adduser $accountName
        passwd $accountName
        usermod -aG sudo $accountName
        echo "%sudo	ALL=(ALL:ALL) ALL" >> ~/etc/sudoers 
        echo "Please login to the new user with [su $accountName]"
        exit
    else
        exit
    fi
else
    sudo pacman -Syyu --noconfirm sudo hyprpaper waybar swaync playerctl polkit-gnome gnome-keyring pipewire wireplumber xdg-desktop-portal-hyprland otf-geist-mono-nerd otf-font-awesome pavucontrol nm-connection-editor networkmanager blueman git base-devel flatpak nemo rofi-wayland neovim foot gdm cpio meson cmake zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search neofetch kdeconnect npm gtk2 gtk3 gtk4
fi

if [ "$(pacman -Q | grep -o -m 1 yay)" != "yay" ];
then
    if [ "$(ls | grep -o -m 1 "yay")" = "yay" ];
    then 
        sudo rm -r ./yay/
    fi
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
fi

yay -S --noconfirm hyprshot nvim-packer-git hy3-git oh-my-zsh-git hyprland-git hyprland-plugin-hyprbars-git nwg-shell

flatpak -y remote-add --system flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak -y install org.mozilla.firefox/x86_64/stable
sudo flatpak override --filesystem="$HOME"/.themes
sudo flatpak override --filesystem="$HOME"/.icons
sudo flatpak override --filesystem="$HOME"/.gtkrc-2.0
sudo flatpak override --env=GTK_THEME=Adwaita-dark
sudo flatpak override --env=ICON_THEME=Adwaita-dark

if [ "$(ls | grep -o -m 1 "kcs-reasonable-configs")" = "kcs-reasonable-configs" ];
then 
    sudo rm -r ./kcs-reasonable-configs/
fi
git clone https://github.com/KCkingcollin/kcs-reasonable-configs
cd kcs-reasonable-configs
mv "$HOME/.config/nvim" "$HOME/.config/nvim.bac" 
mv "$HOME/.config/foot" "$HOME/.config/foot.bac" 
mv "$HOME/.config/hypr" "$HOME/.config/hypr.bac" 
mv "$HOME/.config/waybar" "$HOME/.config/waybar.bac" 
mv "$HOME/.config/swaync" "$HOME/.config/swaync.bac" 
mv "$HOME/.config/rofi" "$HOME/.config/rofi.bac" 
v "$HOME/.zshrc" "$HOME/.zshrc.bac" 
mv "$HOME/.themes" "$HOME/.themes.bac" 
mv "$HOME/.icons" "$HOME/.icons.bac" 
mv "$HOME/.gtkrc-2.0" "$HOME/.gtkrc-2.0.bac" 

location="$(pwd)"

sudo chmod +x "$location"/switch-DEs.sh

yes | cp -rf "$location"/nvim "$location"/foot "$location"/hypr "$location"/waybar "$location"/swaync "$location"/rofi "$HOME/.config/"

yes | cp -rf "$location"/.zshrc "$location"/.themes "$location"/.icons "$location"/.gtkrc-2.0 "$HOME/"

yes | sudo cp -r "$location"/switch-DEs.sh /usr/bin/

yes | sudo cp -r "$location"/switch-DEs.service /etc/systemd/system/

sudo chsh -s /bin/zsh $USER

if [ "$(ls "$HOME/Pictures/" | grep -o -m 1 "background.jpg")" != "background.jpg" ];
then
    mkdir -p "$HOME/Pictures" 
    cp ./background.jpg "$HOME/Pictures/background.jpg"
fi

nvim --headless -c 'autocmd User PackerComplete quitall' -c 'PackerSync'

sudo systemctl start switch-DEs.service
