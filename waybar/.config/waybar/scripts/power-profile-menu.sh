#!/usr/bin/env bash
#
# Waybar power profile menu: switch TLP power profile via wofi
# Uses tlp's built-in modes: performance, balanced, power-saver
#

PROFILE_FILE="/sys/firmware/acpi/platform_profile"
EPP_FILE="/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"
THEME_FILE="$HOME/.config/waybar/theme.css"
MENU_CSS="/tmp/power-profile-menu.css"

generate_menu_css() {
    local fg="#8196a3" bg="#0c0d11"
    if [ -f "$THEME_FILE" ]; then
        fg=$(grep '@define-color foreground' "$THEME_FILE" | grep -oE '#[0-9a-fA-F]{6}' | head -1)
        bg=$(grep '@define-color background' "$THEME_FILE" | grep -oE '#[0-9a-fA-F]{6}' | head -1)
    fi
    fg="${fg:-#8196a3}"
    bg="${bg:-#0c0d11}"

    local fr=$((0x${fg:1:2})) fg_=$((0x${fg:3:2})) fb=$((0x${fg:5:2}))
    local br=$((0x${bg:1:2})) bg_=$((0x${bg:3:2})) bb=$((0x${bg:5:2}))

    local mr=$(((fr * 20 + br * 80) / 100))
    local mg=$(((fg_ * 20 + bg_ * 80) / 100))
    local mb=$(((fb * 20 + bb * 80) / 100))
    local sel_bg=$(printf '#%02x%02x%02x' "$mr" "$mg" "$mb")

    local dr=$(((fr * 30 + br * 70) / 100))
    local dg=$(((fg_ * 30 + bg_ * 70) / 100))
    local db=$(((fb * 30 + bb * 70) / 100))
    local border=$(printf '#%02x%02x%02x' "$dr" "$dg" "$db")

    cat >"$MENU_CSS" <<EOF
window {
    background-color: ${bg};
    border: 1px solid ${border};
    border-radius: 4px;
    font-family: 'JetBrainsMonoNerdFontMono';
    font-size: 12px;
    color: ${fg};
}
#input {
    padding: 6px 12px;
    border: none;
    border-bottom: 1px solid ${border};
    background: transparent;
    color: ${fg};
}
#entry {
    padding: 6px 16px;
    margin: 0 4px;
}
#entry:selected {
    background-color: ${sel_bg};
    border-radius: 2px;
}
EOF
}

get_current_profile() {
    local profile epp
    profile=$(cat "$PROFILE_FILE" 2>/dev/null || echo "unknown")
    epp=$(cat "$EPP_FILE" 2>/dev/null || echo "")

    if [ "$profile" = "performance" ]; then
        echo "performance"
    elif [ "$epp" = "power" ]; then
        # Both balanced and power-saver use power EPP
        # Default to balanced — user can always select power-saver explicitly
        echo "balanced"
    else
        echo "performance"
    fi
}

set_profile() {
    local profile="$1"
    local tlp_mode

    case "$profile" in
        performance)  tlp_mode="performance" ;;
        balanced)     tlp_mode="balanced" ;;
        power-saver)  tlp_mode="power-saver" ;;
        *)            return 1 ;;
    esac

    pkexec tlp "$tlp_mode" 2>/dev/null
    if [ $? -eq 0 ]; then
        notify-send "Power Profile" "Switched to: $profile" 2>/dev/null
        pkill -RTMIN+2 waybar 2>/dev/null
    else
        notify-send "Power Profile" "Failed: $profile" 2>/dev/null
    fi
}

main() {
    generate_menu_css

    local current
    current=$(get_current_profile)

    local items=()
    if [ "$current" = "power-saver" ]; then
        items+=("󰂅 power-saver ✓")
    else
        items+=("󰂅 power-saver")
    fi

    if [ "$current" = "balanced" ]; then
        items+=("󰓅 balanced ✓")
    else
        items+=("󰓅 balanced")
    fi

    if [ "$current" = "performance" ]; then
        items+=("󰠾 performance ✓")
    else
        items+=("󰠾 performance")
    fi

    local selected
    selected=$(printf '%s\n' "${items[@]}" | wofi --dmenu --prompt "" -W 220 -s "$MENU_CSS")

    [ -z "$selected" ] && exit 0

    local profile
    profile=$(echo "$selected" | sed -E 's/^[^a-z]*//' | tr -d ' ✓')

    set_profile "$profile"
}

main
