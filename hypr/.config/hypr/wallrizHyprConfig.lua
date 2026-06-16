local var_wallpaperDir = "~/Pictures/Wallpapers/"
local var_WR = "WallRizz -n -d " .. var_wallpaperDir .. " $themeMode -f \"STD.setenv('enableBlur',true)\""
local var_WallRizz = "kitty -1 -o allow_remote_control=yes -o background_opacity=$overlay_window_opacity --title=WallRizz " .. var_WR
local var_WallRizzRandom = "kitty -1 -o allow_remote_control=yes --class=hidden --title=hidden " .. var_WR .. " -r"

-- WallRizz Grid View

-- windowrulev2 = float, title:^(WallRizz)$

-- windowrulev2 = size 70% 70%, title:^(WallRizz)$

-- windowrulev2 = animation slide top, title:^(WallRizz)$

-- windowrulev2 = dimaround, title:^(WallRizz)$

-- windowrulev2 = pin, title:^(WallRizz)$

-- windowrulev2 = center 1, title:^(WallRizz)$

-- windowrulev2 = bordersize 10, title:^(WallRizz)$

-- windowrulev2 = rounding 20, title:^(WallRizz)$

--

-- Key binds
hl.bind("CTRL + f3", hl.dsp.exec_cmd(var_WallRizz), {
    description = "Apply wallpaper preset",
})
hl.bind(var_mainMod .. " + f3", hl.dsp.exec_cmd(var_WallRizzRandom), {
    description = "Apply random wallpaper",
})
