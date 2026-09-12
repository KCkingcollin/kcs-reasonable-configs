-- ──────────────── LOOKS (Decoration & Animations) ────────────────
-- See https://wiki.hyprland.org/Configuring/Basics/Variables/

local colors = require(os.getenv("HOME") .. "/.config/castle-shell/hypr-colors")

-- ─── Decoration settings ───
hl.config({
    general = {
        border_size = 2,
        -- no_border_on_floating = false
        gaps_in = 5,
        -- gaps_out = {5 ,5 ,5 ,5},
        gaps_out = 5,
        col = {
            active_border = colors.prime_color,
            inactive_border = colors.alt_color,
        },
    },

    decoration = {
        -- See https://wiki.hyprland.org/Configuring/Variables/ for more
        rounding = 10,
        blur = {
            enabled = true,
            size = 3,
            passes = 3,
            new_optimizations = true,
        },
        shadow = {
            enabled = false,
            range = 4,
            render_power = 3,
            color = "rgba(1a1a1aee)",
        },
    },

    animations = {
        enabled = true,
        -- Some default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more
    },
})

-- Layer rules for blur on specific layer surfaces
hl.layer_rule({
    name   = "blur-waybar",
    match  = { namespace = "waybar" },
    blur   = true,
})

hl.layer_rule({
    name   = "blur-rofi",
    match  = { namespace = "rofi" },
    blur   = true,
})

hl.layer_rule({
    name   = "blur-swaync",
    match  = { namespace = "swaync" },
    blur   = true,
})

-- ─── Curves (Bezier & Spring) ───
-- See https://wiki.hyprland.org/Configuring/Advanced-and-Cool/Animations/
hl.curve("myBezier", {
    type   = "bezier",
    points = { { 0.05, 0.9 }, { 0.1, 1.05 } },
})

-- Default spring curve (used for window animations)
hl.curve("defaultSpring", {
    type      = "spring",
    mass      = 1,
    stiffness = 150,
    dampening   = 15,
})

-- ─── Animations ───
hl.animation({
    leaf     = "windows",
    enabled  = true,
    speed    = 7,
    bezier   = "myBezier",
})

hl.animation({
    leaf     = "windowsOut",
    enabled  = true,
    speed    = 7,
    spring   = "defaultSpring",
    style    = "popin 80%",
})

hl.animation({
    leaf     = "border",
    enabled  = true,
    speed    = 10,
    bezier   = "myBezier",
})

hl.animation({
    leaf     = "borderangle",
    enabled  = true,
    speed    = 8,
    bezier   = "myBezier",
})

hl.animation({
    leaf     = "fade",
    enabled  = true,
    speed    = 7,
    bezier   = "myBezier",
})

hl.animation({
    leaf     = "workspaces",
    enabled  = true,
    speed    = 1,
    bezier   = "myBezier",
})

-- ─── Plugin looks settings (hyprbars + hy3 tabs) ───
hl.config({
    plugin = {
        hyprbars = {
            bar_title_enabled       = false,
            bar_padding             = 0,
            bar_height              = 20,
            bar_color               = colors.alt_color,
            bar_precedence_over_border = true,
            bar_part_of_window      = true,
        },

        hy3 = {
            tabs = {
                height          = 10,
                padding         = 5,
                radius        = 4,
                render_text     = false,
                border_width    = 3,
                colors = {
                    active_border           = colors.prime_color,
                    inactive_border         = "0",       -- rgba with alpha 0 (invisible)
                    active                  = colors.alt_color,
                    inactive                = colors.alt_color,
                    focused                 = colors.alt_color,
                    focused_border          = colors.prime_color,
                    active_alt_monitor      = colors.alt_color,
                    active_alt_monitor_border = colors.prime_color,
                },
            },
        },
    },
})
