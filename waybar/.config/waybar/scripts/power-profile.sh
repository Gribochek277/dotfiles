#!/usr/bin/env bash
#
# Waybar custom module: display current power profile
# Reads /sys/firmware/acpi/platform_profile and outputs JSON
#

PROFILE_FILE="/sys/firmware/acpi/platform_profile"

get_profile_info() {
	local profile
	profile=$(cat "$PROFILE_FILE" 2>/dev/null || echo "unknown")

	local text icon class tooltip

	case "$profile" in
	low-power)
		icon=$'\U001f50b' # 🔋 battery leaf
		text="󰂅 low-power"
		class="low-power"
		tooltip="Profile: low-power\nAction: click to switch"
		;;
	balanced)
		icon=$'\U002696' # ⚖ balance
		text="󰓅 balanced"
		class="balanced"
		tooltip="Profile: balanced\nAction: click to switch"
		;;
	performance)
		icon=$'\U001f4a1' # ⚡ zap
		text="󰠾 performance"
		class="performance"
		tooltip="Profile: performance\nAction: click to switch"
		;;
	*)
		text="⚠ unknown"
		class="unknown"
		tooltip="Profile: $profile (unsupported)\nAction: click to switch"
		;;
	esac

	jq -nc --arg text "$text" --arg tooltip "$tooltip" --arg class "$class" \
		'{text:$text, tooltip:$tooltip, class:$class}'
}

get_profile_info
