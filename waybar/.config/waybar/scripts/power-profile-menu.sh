#!/usr/bin/env bash
#
# Waybar power profile menu: switch TLP power profile via rofi
# Uses tlp's built-in modes: performance, balanced, power-saver
#
# 2026-08-16: migrated from wofi to rofi. The menu now follows the
# WallRizz theme automatically (~/.config/rofi/theme.rasi is regenerated
# on every theme apply) instead of hand-generating wofi CSS from
# ~/.config/waybar/theme.css. wofi itself was also broken by a corrupt
# ~/.config/wofi/config (fixed separately).

ROFI_THEME="$HOME/.config/rofi/theme.rasi"

rofi_dmenu() {
    # dmenu-compatible frontend, themed like the rest of the environment
    if [ -f "$ROFI_THEME" ]; then
        rofi -dmenu -theme "$ROFI_THEME" -font "JetBrainsMono Nerd Font Mono 12" \
            -width 30 -lines 3 "$@"
    else
        rofi -dmenu -font "JetBrainsMono Nerd Font Mono 12" -width 30 -lines 3 "$@"
    fi
}

get_current_profile() {
	local profile
	profile=$(tlpctl get 2>/dev/null || echo "unknown")

	case "$profile" in
	performance|balanced|power-saver) echo "$profile" ;;
	*) echo "unknown" ;;
	esac
}

set_profile() {
	local profile="$1"

	case "$profile" in
	performance|balanced|power-saver) ;;
	*) return 1 ;;
	esac

	tlpctl "$profile" >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		notify-send "Power Profile" "Switched to: $profile" 2>/dev/null
		pkill -RTMIN+2 waybar 2>/dev/null
	else
		notify-send "Power Profile" "Failed: $profile" 2>/dev/null
	fi
}

main() {
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
	selected=$(printf '%s\n' "${items[@]}" | rofi_dmenu)

	[ -z "$selected" ] && exit 0

	local profile
	profile=$(echo "$selected" | sed -E 's/^[^a-z]*//' | tr -d ' ✓')

	set_profile "$profile"
}

main
