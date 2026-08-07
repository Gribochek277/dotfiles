#!/usr/bin/env bash
#
# Waybar custom module: display current TLP power profile
# Reads the active profile from tlp-pd and shows CPU EPP as diagnostics
#

EPP_FILE="/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"

get_profile_info() {
	local profile epp
	profile=$(tlpctl get 2>/dev/null || echo "unknown")
	epp=$(cat "$EPP_FILE" 2>/dev/null || echo "")

	local text class tooltip

	case "$profile" in
	performance)
		text="󰠾 performance"
		class="performance"
		tooltip="TLP: performance\nCPU EPP: $epp\nAction: click to switch"
		;;
	balanced)
		text="󰓅 balanced"
		class="balanced"
		tooltip="TLP: balanced\nCPU EPP: $epp\nAction: click to switch"
		;;
	power-saver)
		text="󰂅 power-saver"
		class="power-saver"
		tooltip="TLP: power-saver\nCPU EPP: $epp\nAction: click to switch"
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
