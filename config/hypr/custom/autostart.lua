-- ──────────────── AUTOSTART ────────────────
-- Services and programs to launch on Hyprland start

hl.env("HYPRSHOT_DIR", "$HOME/Pictures/Screenshots/")
hl.env("QT_STYLE_OVERRIDE", "Adwaita-dark")
hl.env("TERMINAL", "$term")
hl.env("XCURSOR_SIZE", "24")
hl.env("SHELL", "/bin/zsh")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_STYLE_OVERRIDE", "Adwaita-Dark")

-- ─── Core services ───
hl.on("hyprland.start", function ()
    hl.exec_cmd("hyprpm reload -n")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("xhost +si:localuser:root")
    hl.exec_cmd("hyprpaper")

    -- ─── User systemd services ───
    hl.exec_cmd("systemctl start --user waybar-hyprland.service")
    hl.exec_cmd("systemctl start --user theme-check.service")
    hl.exec_cmd("systemctl start --user swaync.service")

    -- ─── Portal services ───
    hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("systemctl --user restart xdg-desktop-portal.service")
    hl.exec_cmd("systemctl --user start xdg-desktop-portal-hyprland.service")
    hl.exec_cmd("systemctl --user start xdg-desktop-portal-gtk.service")
    hl.exec_cmd("systemctl --user restart pipewire")

    -- ─── GNOME gsettings (fonts, theme, cursor) ───
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'OpenDyslexicNerdFont 12'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface document-font-name 'OpenDyslexicNerdFont 12'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface monospace-font-name 'OpenDyslexicMNerdFontMono 12'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic'")

    -- ─── Additional services ───
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprlock")

    -- ─── Personal startup apps ───
    hl.exec_cmd("kdeconnectd")
    hl.exec_cmd("kdeconnect-indicator")
    hl.exec_cmd("ckb-next --background")
    hl.exec_cmd("otd-daemon")
    hl.exec_cmd("easyeffects --gapplication-service")
    hl.exec_cmd(_G.term .. " -e /bin/zsh -c 'clear && fastfetch && /bin/zsh'")
end)

hl.on("hyprland.shutdown", function ()
end)
