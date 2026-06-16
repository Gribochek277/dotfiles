-- ####################

-- ## LOOK AND FEEL ###

-- ####################

-- https://wiki.hyprland.org/Configuring/Variables/#general
hl.config({
    general = {
        gaps_in = var_gaps_in,
        gaps_out = var_gaps_out,
        border_size = var_border_size,
    },
})

-- https://wiki.hyprland.org/Configuring/Variables/#variable-types for info about colors
hl.config({
    general = {
        col = {
            active_border = {
                colors = {var_color_border_active, var_color_border_active},
                angle = 45,
            },
            inactive_border = var_color_border_inactive,
        },
    },
})

-- Set to true enable resizing windows by clicking and dragging on borders and gaps
hl.config({
    general = {
        resize_on_border = true,
    },
})

-- Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on
hl.config({
    general = {
        allow_tearing = false,
        layout = "dwindle",
    },
})

-- Group settings
hl.config({
    group = {
        groupbar = {
            enabled = true,
            gradients = true,
            text_color = var_color_text,
            text_color_inactive = var_color_text,
            text_color_locked_active = var_color_text,
        },
    },
})
