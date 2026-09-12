-- ──────────────── WINDOW RULES ────────────────
-- See https://wiki.hyprland.org/Configuring/Window-Rules/ for more

hl.window_rule({
    name   = "float-on-match-class",
    match  = "^(galculator|org\\.gnome\\.Calculator|nm-connection-editor|blueman-manager|pavucontrol)$",
    float = true,
})
