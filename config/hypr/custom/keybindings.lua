-- ──────────────── KEY BINDINGS ────────────────
-- See https://wiki.hyprland.org/Configuring/Binds/ for more

local mainMod = _G.mainMod -- Main modifier for keybinds located in settings
local hy3 = hl.plugin.hy3

-- ─── App launchers ───
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(_G.browser))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(_G.editor))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd(_G.exit))
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd(_G.filemanager))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(_G.menu))
hl.bind("CTRL + ALT + T", hl.dsp.exec_cmd(_G.term .. " -e /bin/zsh -c 'clear && fastfetch && /bin/zsh'"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(_G.term .. " -e /bin/zsh -c 'clear && fastfetch && /bin/zsh'"))

-- ─── Window management ───
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen())
hl.bind("F11", hl.dsp.window.fullscreen())
-- hl.bind(mainMod .. " + I",     nil,   "pin")
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind("ALT + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exit())
hl.bind(mainMod .. " + V", hl.dsp.window.float())
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload")) -- reload Hyprland
-- hl.bind(mainMod .. " + SHIFT + Z", "special",                "movetoworkspace")  -- move to special workspace
-- hl.bind(mainMod .. " + Z",     nil,    "togglespecialworkspace")

-- ─── Brightness (repeatable) ───
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"))
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"))

-- -- ─── Volume (1% steps, repeatable) ───
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"))
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 1%-"))
hl.bind("XF86AudioRaiseVolume",   hl.dsp.exec_cmd("wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 1%+"))

-- ─── Power & sleep (repeatable) ───
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("systemctl suspend"))
hl.bind("code:134", hl.dsp.exec_cmd("systemctl suspend"))
hl.bind(mainMod .. " + ALT + s", hl.dsp.exec_cmd("systemctl suspend"))
hl.bind(mainMod .. " + ALT + p", hl.dsp.exec_cmd("shutdown now"))
hl.bind(mainMod .. " + code:134", hl.dsp.exec_cmd("shutdown now"))

-- ─── Hyprlock ───
hl.bind(mainMod .. " + CTRL + l", hl.dsp.exec_cmd("hyprlock"))

-- ─── Media player controls (repeatable) ───
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("F10", hl.dsp.exec_cmd("playerctl play-pause"))

-- ─── Screenshots ───
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region"))       -- full screen (region auto-select
hl.bind("ALT + Print", hl.dsp.exec_cmd("hyprshot -m window -a"))       -- active monitor screenshot
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("hyprshot -m window"))         -- focused window
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m region -s"))        -- selected region

-- ─── Groups ───
hl.bind("ALT + G", hy3.make_group("tab", {ephemeral = "force"}))
hl.bind(mainMod .. " + G", hy3.change_group("toggletab"))
hl.bind("ALT + left", hy3.move_focus("l"))
hl.bind("ALT + right", hy3.move_focus("r"))
hl.bind("ALT + up", hy3.move_focus("u"))
hl.bind("ALT + down", hy3.move_focus("d"))
hl.bind("ALT + h", hy3.move_focus("l"))
hl.bind("ALT + l", hy3.move_focus("r"))
hl.bind("ALT + SHIFT + k", hy3.move_focus("u"))
hl.bind("ALT + SHIFT + j", hy3.move_focus("d"))
-- hl.bind("mouse:272", hy3.focus_tab({index = 0, mouse = "prioritize_hovered"}))

-- ─── Fixing floating windows with alt tab ───
hl.bind("ALT + h", hl.dsp.window.alter_zorder({ mode = "top", window = "activewindow" }))
hl.bind("ALT + l", hl.dsp.window.alter_zorder({ mode = "top", window = "activewindow" }))
hl.bind("ALT + SHIFT + k", hl.dsp.window.alter_zorder({ mode = "top", window = "activewindow" }))
hl.bind("ALT + SHIFT + j", hl.dsp.window.alter_zorder({ mode = "top", window = "activewindow" }))
hl.bind("ALT + left", hl.dsp.window.alter_zorder({ mode = "top", window = "activewindow" }))
hl.bind("ALT + right", hl.dsp.window.alter_zorder({ mode = "top", window = "activewindow" }))
hl.bind("ALT + up", hl.dsp.window.alter_zorder({ mode = "top", window = "activewindow" }))
hl.bind("ALT + down", hl.dsp.window.alter_zorder({ mode = "top", window = "activewindow" }))
hl.bind("ALT + Tab", hl.dsp.window.cycle_next({ next = true, floating = true }))
hl.bind("ALT + Tab", hl.dsp.window.alter_zorder({ mode = "top", window = "activewindow" }))

-- ─── Move window ───
-- TODO: manual review on line 84 — no mapping for dispatcher "hy3:movewindow"
hl.bind(mainMod .. " + left", hy3.move_window("l"))
hl.bind(mainMod .. " + right", hy3.move_window("r"))
hl.bind(mainMod .. " + up", hy3.move_window("u"))
hl.bind(mainMod .. " + down", hy3.move_window("d"))
hl.bind(mainMod .. " + h", hy3.move_window("l"))
hl.bind(mainMod .. " + l", hy3.move_window("r"))
hl.bind(mainMod .. " + k", hy3.move_window("u"))
hl.bind(mainMod .. " + j", hy3.move_window("d"))
hl.bind(mainMod .. " + ALT + h", hy3.change_group("opposite"))
hl.bind(mainMod .. " + ALT + l", hy3.change_group("opposite"))
hl.bind(mainMod .. " + ALT + left", hy3.change_group("opposite"))
hl.bind(mainMod .. " + ALT + right", hy3.change_group("opposite"))

hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

-- SWITCH WORKSPACES with mainMod + [0-9]
hl.bind("CTRL + ALT + right", hl.dsp.focus({ workspace = "+1" }))
hl.bind("CTRL + ALT + left", hl.dsp.focus({ workspace = -1 }))
hl.bind("CTRL + ALT + l", hl.dsp.focus({ workspace = "+1" }))
hl.bind("CTRL + ALT + h", hl.dsp.focus({ workspace = -1 }))
hl.bind(mainMod .. " + 1", hl.dsp.focus({ workspace = 1 }))
hl.bind(mainMod .. " + 2", hl.dsp.focus({ workspace = 2 }))
hl.bind(mainMod .. " + 3", hl.dsp.focus({ workspace = 3 }))
hl.bind(mainMod .. " + 4", hl.dsp.focus({ workspace = 4 }))
hl.bind(mainMod .. " + 5", hl.dsp.focus({ workspace = 5 }))
hl.bind(mainMod .. " + 6", hl.dsp.focus({ workspace = 6 }))
hl.bind(mainMod .. " + 7", hl.dsp.focus({ workspace = 7 }))
hl.bind(mainMod .. " + 8", hl.dsp.focus({ workspace = 8 }))
hl.bind(mainMod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mainMod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- MOVE ACTIVE WINDOW TO A WORKSPACE with mainMod + SHIFT + [0-9]
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ workspace = "+1" }))
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ workspace = -1 }))
hl.bind(mainMod .. " + SHIFT + Page_up", hl.dsp.window.move({ workspace = "+1" }))
hl.bind(mainMod .. " + SHIFT + Page_down", hl.dsp.window.move({ workspace = -1 }))
hl.bind(mainMod .. " + SHIFT + l", hl.dsp.window.move({ workspace = "+1" }))
hl.bind(mainMod .. " + SHIFT + h", hl.dsp.window.move({ workspace = -1 }))
hl.bind(mainMod .. " + SHIFT + 1", hl.dsp.window.move({ workspace = 1 }))
hl.bind(mainMod .. " + SHIFT + 2", hl.dsp.window.move({ workspace = 2 }))
hl.bind(mainMod .. " + SHIFT + 3", hl.dsp.window.move({ workspace = 3 }))
hl.bind(mainMod .. " + SHIFT + 4", hl.dsp.window.move({ workspace = 4 }))
hl.bind(mainMod .. " + SHIFT + 5", hl.dsp.window.move({ workspace = 5 }))
hl.bind(mainMod .. " + SHIFT + 6", hl.dsp.window.move({ workspace = 6 }))
hl.bind(mainMod .. " + SHIFT + 7", hl.dsp.window.move({ workspace = 7 }))
hl.bind(mainMod .. " + SHIFT + 8", hl.dsp.window.move({ workspace = 8 }))
hl.bind(mainMod .. " + SHIFT + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(mainMod .. " + SHIFT + 0", hl.dsp.window.move({ workspace = 10 }))

-- SCROLL THROUGH EXISTING WORKSPACES with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- MOVE/RESIZE WINDOWS with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag())
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize())
hl.bind(mainMod .. " + ALT + mouse:272", hl.dsp.window.resize())

