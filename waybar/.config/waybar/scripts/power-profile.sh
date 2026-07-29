#!/usr/bin/env bash
#
# Waybar custom module: display current TLP power profile
# Reads /sys/firmware/acpi/platform_profile + EPP to determine mode
#

PROFILE_FILE="/sys/firmware/acpi/platform_profile"
EPP_FILE="/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference"

get_profile_info() {
    local profile epp
    profile=$(cat "$PROFILE_FILE" 2>/dev/null || echo "unknown")
    epp=$(cat "$EPP_FILE" 2>/dev/null || echo "")

    local text class tooltip

    case "$profile" in
        performance)
            text="󰠾 performance"
            class="performance"
            tooltip="TLP: performance\nCPU EPP: $epp\nAction: click to switch"
            ;;
        low-power)
            if [ "$epp" = "power" ]; then
                # Could be balanced or power-saver — check TLP status
                local tlp_mode
                tlp_mode=$(tlp status 2>/dev/null | grep -oP '(?<=Profile:\s)\K\S+' || echo "")
                case "$tlp_mode" in
                    SAV)
                        text="󰂅 power-saver"
                        class="power-saver"
                        tooltip="TLP: power-saver\nCPU EPP: $epp\nAction: click to switch"
                        ;;
                    *)
                        text="󰓅 balanced"
                        class="balanced"
                        tooltip="TLP: balanced\nCPU EPP: $epp\nAction: click to switch"
                        ;;
                esac
            else
                text="󰓅 balanced"
                class="balanced"
                tooltip="Profile: low-power\nCPU EPP: $epp\nAction: click to switch"
            fi
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
