-- ############

-- ## INPUT ###

-- ############

-- https://wiki.hyprland.org/Configuring/Variables/#input
hl.config({
    input = {
        kb_layout = "us,ru,ua",
        kb_model = "",
        kb_options = "grp:alt_shift_toggle,ctrl:nocaps",
        kb_rules = "",
        resolve_binds_by_sym = 0,
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            disable_while_typing = false,
            natural_scroll = true,
        },
    },
})

-- https://wiki.hyprland.org/Configuring/Variables/#gestures
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

-- Per-device input configs

-- See https://wiki.hyprland.org/Configuring/Keywords/#per-device-input-configs for more
hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})
