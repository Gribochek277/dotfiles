-- #######################################################################################

-- HYPRLAND CONFIG - MODULAR STRUCTURE

-- This is the main configuration file that sources all other config files

-- For a full list of settings and options, see the wiki:

-- https://wiki.hyprland.org/Configuring/Configuring-Hyprland/

-- #######################################################################################

-- ##########################

-- ## CONFIGURATION FILES ###

-- ##########################

-- Core configuration
require("config.variables")
require("config.environment")
require("config.programs")

-- Display and monitors
require("monitors")

-- Autostart applications
require("config.autostart")

-- Input configuration (keyboard, mouse, touchpad, gestures)
require("config.input")

-- Look and feel
require("config.look-and-feel.general")
require("config.look-and-feel.decoration")
require("config.look-and-feel.animations")
require("config.look-and-feel.colors")

-- Layout configuration
require("config.layouts.dwindle")
require("config.layouts.master")
require("config.misc")

-- Keybindings (organized by category)
require("config.keybinds.main")
require("config.keybinds.media")
require("config.keybinds.window")
require("config.keybinds.workspace")
require("config.keybinds.apps")

-- Window rules
require("config.window-rules")

-- Additional theme files (if they exist)
require("wallrizHyprConfig")
require("WallRizzTheme")

-- HyprMod managed settings
require("hyprland-gui")

-- hyprwhspr - Toggle mode (added by hyprwhspr setup)

-- Press once to start, press again to stop
hl.bind("CTRL + F9", hl.dsp.exec_cmd("/usr/lib/hyprwhspr/config/hyprland/hyprwhspr-tray.sh record"), {
    description = "Speech-to-text",
})

hl.bind("XF86NotificationCenter", hl.dsp.exec_cmd("/usr/lib/hyprwhspr/config/hyprland/hyprwhspr-tray.sh record"), {
    description = "Speech-to-text",
})
