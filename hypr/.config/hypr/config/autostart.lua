-- ################

-- ## AUTOSTART ###

-- ################

-- Autostart necessary processes (like notifications daemons, status bars, etc.)

-- Or execute your favorite apps at launch like this:

-- System utilities
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar & nm-applet")
    hl.exec_cmd("blueman-applet")
    hl.exec_cmd("udiskie -t")
    hl.exec_cmd("xhost +SI:localuser:root")
    hl.exec_cmd("syncthing")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("localsend --hidden")
    hl.exec_cmd("systemctl --user start hyprwhspr.service")
end)

-- exec-once = llama-server -hf lilyanatia/Ternary-Bonsai-8B-GGUF:Q2_K -c 64000

-- Workaround audio bug
hl.on("hyprland.start", function()
    hl.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
    hl.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
end)

-- Applications in special workspaces
hl.on("hyprland.start", function()
    hl.exec_cmd("[workspace special:vpn silent] flatpak run com.surfshark.Surfshark")
end)

-- exec-once = [workspace special:temp silent] flatpak run com.brave.Browser --app=https://habitica.com/
hl.on("hyprland.start", function()
    hl.exec_cmd("[workspace special:magic silent] flatpak run org.telegram.desktop")
end)

-- exec-once = [workspace special:magic silent] bluemail

-- exec-once = [workspace special:temp silent] slimbookbattery --minimize

-- Development tools

-- exec-once = PORT=1488 npx vibe-kanban
