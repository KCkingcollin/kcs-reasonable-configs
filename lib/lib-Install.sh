RepoLocation=""
ArchPackages=""
AurPackages=""
UserName=""
HomeDir=""

# clone/find the repo in the users home directory or current directory
# if true is sent to the function then it'll attempt to mv the repo location to the home dir of the user
function CloneRepo {
    if [ ! -z "$UserName" ]; then
        HomeDir=$(getent passwd "$UserName" | cut -d: -f6)
        cd "$HomeDir" || return 1
        mv "$RepoLocation" "$HomeDir/kcs-reasonable-configs" &> /dev/null
    fi
    if ! grep -q "kcs-reasonable-configs" <(pwd) <(ls); then
        git clone https://github.com/KCkingcollin/kcs-reasonable-configs
    fi
    if [ -d "kcs-reasonable-configs" ]; then
        cd kcs-reasonable-configs || return 1
    fi
    RepoLocation="$(pwd)"
    ArchPackages="$RepoLocation/arch-packages"
    AurPackages="$RepoLocation/aur-packages"
    if [ ! -z "$UserName" ]; then
        chown -R "$UserName":"$UserName" .
    fi
    return 0
}

function AddUserToSudo {
    UserName="$1"
    groupadd sudo 
    usermod -aG sudo "$UserName"
    sed -i '/%sudo/ s/^#//' /etc/sudoers
    echo "$UserName"
    return 0
}

function CreateAccount {
    printf "Name of the account?: "
    read -r UserName
    printf '\n'
    useradd -m "$UserName"
    passwd "$UserName" || return 1
    AddUserToSudo "$UserName"
    return 0
}

function GetAccount {
    echo "Provid the account usernemae you want to set the environment up with"
    printf "Username?: "
    read -r UserName
    printf '\n'
    AddUserToSudo "$UserName"
    return 0
}

function CreateSudoUser {
    echo "$UserName ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/tempRule
}

function RemoveSudoUser {
    if rm /etc/sudoers.d/tempRule 2>&1 | grep -q "No such file or directory"; then
        echo "Error removing sudo user, system is not secure"
        return 1
    fi
    return 0
}

function CheckAndFixFstab {
    if [ "$#" -lt 1 ]; then
        echo "No devices given."
        return 1
    fi
    for elm in range "$@"; do
        sed -i "/^#/! s|$elm|UUID=$(blkid | grep "$elm" | cut -d'"' -f2)|" /etc/fstab
    done
    return 0
}

function InstallYayPackages {
    if ! pacman -Q | grep -q "yay"; then
        if [ ! -d "yay-bin" ]; then 
            git clone https://aur.archlinux.org/yay-bin.git
        fi
        cd yay-bin || return 1
        chown -R "$UserName":"$UserName" .
        sudo -S -u "$UserName" makepkg -si --noconfirm
        cd ..
    fi
    xargs -a "$AurPackages" sudo -S -u "$UserName" yay -Sy --noconfirm
}

function ChrootSetup {
    genfstab -U / >> /etc/fstab
    CheckAndFixFstab "$@" || return 1
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
    pacman -Syu --noconfirm
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=ARCH || return 1
    grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck || return 1
    grub-mkconfig -o /boot/grub/grub.cfg || return 1
    echo -e "\033[32m\nChroot Setup Done\033[0m"
    CreateAccount
    return 0
}

function ExtraPackages {
    CreateSudoUser
    CloneRepo || return 1

    InstallYayPackages

    if [ ! -d "castle-shell" ]; then 
        git clone https://github.com/KCkingcollin/castle-shell || return 1
    fi
    cd castle-shell/color-checker || return 1
    go build -o /usr/bin/color-checker
    cd ../..

    flatpak override --filesystem="/home/$UserName"/.themes
    flatpak override --filesystem="/home/$UserName"/.icons
    flatpak override --filesystem="/home/$UserName"/.gtkrc-2.0
    flatpak override --env=GTK_THEME=Adwaita-dark
    flatpak override --env=ICON_THEME=Adwaita-dark

    RemoveSudoUser || return 1
    echo -e "\033[32m\nExtra Packages Installed\033[0m"
    return 0
}

function ConfigSetup {
    CreateSudoUser
    CloneRepo || return 1

    mv "$HomeDir"/.config/nvim "$HomeDir"/.config/nvim.bac &> /dev/null
    mv "$HomeDir"/.config/fastfetch "$HomeDir"/.config/fastfetch.bac &> /dev/null
    mv "$HomeDir"/.config/kitty "$HomeDir"/.config/foot.bac &> /dev/null
    mv "$HomeDir"/.config/hypr "$HomeDir"/.config/hypr.bac &> /dev/null
    mv "$HomeDir"/.config/waybar "$HomeDir"/.config/waybar.bac &> /dev/null
    mv "$HomeDir"/.config/swaync "$HomeDir"/.config/swaync.bac &> /dev/null
    mv "$HomeDir"/.config/rofi "$HomeDir"/.config/rofi.bac &> /dev/null
    mv "$HomeDir"/.config/castle-shell "$HomeDir"/.config/castle-shell.bac &> /dev/null
    mv "$HomeDir"/.zshrc "$HomeDir"/.zshrc.bac &> /dev/null
    mv "$HomeDir"/.themes "$HomeDir"/.themes.bac &> /dev/null
    mv "$HomeDir"/.icons "$HomeDir"/.icons.bac &> /dev/null
    mv "$HomeDir"/.gtkrc-2.0 "$HomeDir"/.gtkrc-2.0.bac &> /dev/null

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

    sudo -S -u "$UserName" mkdir "$HomeDir"/.config &> /dev/null
    cp -rfp config/* "$HomeDir"/.config/
    cp -rfp ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 "$HomeDir"/
    mv "$HomeDir"/.config/hypr/hyprland.conf "$HomeDir"/.config/hypr/hyprland.conf.bac
    cp -rfp ./hyprland.conf.once "$HomeDir"/.config/hypr/hyprland.conf
    chown -R "$UserName":"$UserName" "$HomeDir"

    mkdir /root/.config &> /dev/null
    cp -rf config/* /root/.config/
    cp -rf etc/* /etc/
    cp -rf ./.zshrc ./.themes ./.icons ./.gtkrc-2.0 /root/
    cp -rf ./switch-DEs.sh /usr/bin/switch-DEs
    cp -rf ./theme-check.service ./waybar-hyprland.service /usr/lib/systemd/user/
    cp -rf ./switch-DEs.service  /etc/systemd/system/
    chown -R root:root /root/

    cp -rf ./AfterInstall.sh /bin/
    echo "$UserName    ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/AfterInstallRule

    chsh -s /bin/zsh "$UserName"
    chsh -s /bin/zsh root

    if [ ! -d "$HomeDir/Pictures/background.jpg" ];
    then
        sudo -S -u "$UserName" mkdir -p "$HomeDir"/Pictures &> /dev/null
        cp -fp ./background.jpg "$HomeDir"/Pictures/background.jpg
    fi

    sudo -S -u "$UserName" gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
    sudo -S -u "$UserName" gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
    gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

    rate-mirrors --allow-root --save /etc/pacman.d/mirrorlist arch

    bash -c echo '[User]                        
    Session=hyprland
    XSession=hyprland
    Icon="$UserName"/.face
    SystemAccount=false' > /var/lib/AccountsService/users/"$UserName"

    RemoveSudoUser || return 1
    echo -e "\033[32m\nConfigs Installed\033[0m"
    return 0
}

export RepoLocation ArchPackages AurPackages UserName
