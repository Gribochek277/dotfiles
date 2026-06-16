-- https://wiki.hyprland.org/Configuring/Variables/#decoration
hl.config({
    decoration = {
        rounding = var_rounding,
    },
})

-- Change transparency of focused and unfocused windows
hl.config({
    decoration = {
        active_opacity = 1,
        inactive_opacity = 1,
        shadow = {
            enabled = true,
        },
    },
})

-- https://wiki.hyprland.org/Configuring/Variables/#blur
hl.config({
    decoration = {
        blur = {
            enabled = false,
            size = 1,
            passes = 3,
            vibrancy = 0.6969,
        },
    },
})
