-- ###################

-- ## KEYBINDINGS  ###

-- ###################

-- See https://wiki.hyprland.org/Configuring/Keywords/

-- See https://wiki.hyprland.org/Configuring/Binds/ for more

-- ## Basic Window Management ###

-- Terminal
hl.bind(var_mainMod .. " + RETURN", hl.dsp.exec_cmd(var_terminal))

-- Kill window
hl.bind("ALT + F4", hl.dsp.window.close())
hl.bind("ALT + Super_L", hl.dsp.window.close())

-- Fullscreen
hl.bind(var_mainMod .. " + F", hl.dsp.window.fullscreen())

-- File manager
hl.bind("XF86Explorer", hl.dsp.exec_cmd(var_terminal .. " -e " .. var_fileManager))
hl.bind(var_mainMod .. " + E", hl.dsp.exec_cmd(var_terminal .. " -e " .. var_fileManager))
hl.bind(var_mainMod .. " + CTRL + E", hl.dsp.exec_cmd("nautilus"))

-- Floating and pseudo-tiling
hl.bind(var_mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))

-- Window grouping
hl.bind(var_mainMod .. " + T", hl.dsp.group.toggle())
hl.bind("CTRL + TAB", hl.dsp.group.next())

-- ## Navigation ###

-- Move focus with vim keys
hl.bind(var_mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(var_mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(var_mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(var_mainMod .. " + j", hl.dsp.focus({ direction = "down" }))

-- Move/resize windows with mouse
hl.bind(var_mainMod .. " + mouse:272", hl.dsp.window.drag(), {
    mouse = true,
})
hl.bind(var_mainMod .. " + mouse:273", hl.dsp.window.resize(), {
    mouse = true,
})
hl.bind(var_mainMod .. " + TAB", hl.dsp.window.drag(), {
    mouse = true,
})
hl.bind(var_mainMod .. " + Q", hl.dsp.window.resize(), {
    mouse = true,
})

-- ## Application Launcher ###

-- Wofi menu
hl.bind(var_mainMod .. " + R", hl.dsp.exec_cmd(var_menu))

-- Screenshots
hl.bind(var_mainMod .. " + PRINT", hl.dsp.exec_cmd("hyprshot -m window"))
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m output"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region"))

-- Obsidian
hl.bind(var_mainMod .. " + F12", hl.dsp.exec_cmd("obsidian"))

-- Web UI
hl.bind("XF86Favorites", hl.dsp.exec_cmd("sh /home/serhii/.config/hypr/scripts/open-webui.sh"))
hl.bind("Super_L + F12", hl.dsp.exec_cmd("sh /home/serhii/.config/hypr/scripts/open-webui.sh"))

-- Image generation
hl.bind(var_mainMod .. " + I", hl.dsp.exec_cmd(var_terminal .. " ~/StandaloneApplications/ImageGen/webui.sh --use-cpu all --no-half --api"))
hl.bind(var_mainMod .. " + CTRL + I", hl.dsp.exec_cmd(var_terminal .. " /home/serhii/StandaloneApplications/ImageGen/EasyDiffusion/Easy-Diffusion-Linux/easy-diffusion/start.sh"))

-- ## System ###

-- Lock screen
hl.bind(var_mainMod .. " + Escape", hl.dsp.exec_cmd("hyprlock"))

-- Restart waybar
hl.bind(var_mainMod .. " + W", hl.dsp.exec_cmd("~/.config/hypr/scripts/restart_waybar.sh"))

-- Toggle ollama
hl.bind(var_mainMod .. " + O", hl.dsp.exec_cmd("~/.config/hypr/toggle_ollama.sh"))

-- Monitor management
hl.bind(var_mainMod .. " + left", hl.dsp.workspace.move({ monitor = "l" }))
hl.bind(var_mainMod .. " + right", hl.dsp.workspace.move({ monitor = "r" }))
hl.bind(var_mainMod .. " + D", hl.dsp.exec_cmd("wayscriber --daemon-toggle"))

-- Device toggle
hl.bind("CTRL + F12", hl.dsp.exec_cmd("/home/serhii/.config/hypr/scripts/toggle-device.sh"))

-- Hyprland cheats
hl.bind("SUPER + F1", hl.dsp.exec_cmd("~/.config/hypr/show-hypr-cheats.sh"))

-- Menu launcher
hl.bind("CTRL + " .. var_mainMod .. " + s", hl.dsp.exec_cmd("flatpak run com.brave.Browser --app=http://100.110.77.11:8081/"))
hl.bind("CTRL + m", hl.dsp.exec_cmd(var_terminal .. " -e ~/.menu/menu"))

