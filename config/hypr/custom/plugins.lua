-- ──────────────── PLUGIN LOAD & CONFIGURATION ────────────────
-- See https://wiki.hyprland.org/Configuring/Plugins/

-- hl.plugin("/usr/lib/libhy3.so")
-- hl.plugin("/usr/lib/hyprland-plugins/hyprbars.so")

hl.config({
    plugin = {
        hyprbars = {},  -- looks handled in looks.lua

        hy3 = {
            node_collapse_policy = 0,       -- default: 2
            tabs   = {},                    -- tab looks handled in looks.lua
            autotile = {
                enable         = true,      -- default: false
                trigger_width  = 0,          -- default: 0 (disabled)
                trigger_height = 0,           -- default: 0 (disabled)
            },
        },

        -- overview = {
        --     exitOnClick  = true,
        --     exitOnSwitch = true,
        -- },

        -- hyprexpo disabled (uncomment if you want to enable it)
        -- hyprexpo = {
        --     columns          = 2,
        --     gap_size         = 20,
        --     bg_col           = "rgb(111111)",
        --     workspace_method = "center current",
        --     enable_gesture   = true,
        --     gesture_fingers  = 3,
        --     gesture_distance = 300,
        --     gesture_positive = false,
        -- },
    },
})
