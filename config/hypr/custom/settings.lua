-- ──────────────── SETTINGS & INPUT ────────────────
-- See https://wiki.hyprland.org/Configuring/Keywords/ for more

-- ─── Main Modifier ───
_G.mainMod     = "SUPER"

-- ─── Program variables (shared with keybindings.lua via _G) ───
_G.term        = "kitty"
_G.browser     = "firefox"
_G.filemanager = "nemo"
_G.editor      = _G.term .. " -e nvim"
_G.launcher    = "command -v hyprlauncher >/dev/null 2>&1 && hyprlauncher || rofi -show"
_G.exit        = "$_G.launcher"
_G.menu        = "rofi -show"

-- ─── General settings ───
hl.config({
    -- ─── General settings ───
    general = {
        resize_on_border      = true,
        extend_border_grab_area = true,
        hover_icon_on_border  = true,
        layout                = "hy3",
        snap = {
            enabled = true,
        },
    },

    -- ─── Input settings ───
    input = {
        kb_layout             = "us,de",
        kb_options            = "grp:alt_shift_toggle",
        accel_profile         = "flat",
        follow_mouse          = 1,
        mouse_refocus         = true,
        float_switch_override_focus = 2,
        scroll_factor         = 1.0,

        touchpad = {
            disable_while_typing = true,
            natural_scroll       = true,
            scroll_factor        = 1.0,
            tap_to_click         = true,
        },

        numlock_by_default    = true,
    },

    -- ─── Misc ───
    misc = {
        font_family           = "OpenDyslexicNerdFont",
        splash_font_family    = "OpenDyslexicNerdFont",  -- splash text on startup
    },
})
