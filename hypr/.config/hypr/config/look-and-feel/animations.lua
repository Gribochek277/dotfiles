-- https://wiki.hyprland.org/Configuring/Variables/#animations
hl.config({
    animations = {
        enabled = true,
    },
})

-- Default animations, see https://wiki.hyprland.org/Configuring/Animations/ for more
hl.animation({
    leaf = "windows",
    enabled = true,
    speed = 4,
    bezier = "default",
})
hl.animation({
    leaf = "windowsOut",
    enabled = true,
    speed = 6,
    bezier = "default",
    style = "popin 80%",
})
hl.animation({
    leaf = "border",
    enabled = true,
    speed = 1,
    bezier = "default",
})
hl.animation({
    leaf = "borderangle",
    enabled = true,
    speed = 8,
    bezier = "default",
})
hl.animation({
    leaf = "fade",
    enabled = true,
    speed = 1,
    bezier = "default",
})
hl.animation({
    leaf = "workspaces",
    enabled = true,
    speed = 1,
    bezier = "default",
})
