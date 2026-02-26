#!/usr/bin/env bash
set -euo pipefail

INPUT_CONF="$HOME/.config/hypr/config/input.conf"

# Function to toggle a single device in config
toggle_device() {
    local device_name="$1"
    local new_status

    # Find the line with device name and read current enabled status
    local current=$(grep -A 1 "name = $device_name" "$INPUT_CONF" | grep enabled | awk '{print $3}' || echo "1")

    # Toggle: 1 -> 0, 0 -> 1
    if [ "$current" = "1" ]; then
        new_status=0
    else
        new_status=1
    fi

    # Replace the enabled value using Python with multiline match
    python3 << EOF
import re

with open('$INPUT_CONF', 'r') as f:
    lines = f.readlines()

device_pattern = re.escape('$device_name')
# Match: device block for this device
pattern = re.compile(r'(device\s*\{\s*\n\s*' + device_pattern + r'\s*\n\s*enabled\s*=\s*[0-9]+\s*\n\s*\})')

replacement = r'\1enabled = $new_status'
content = ''.join(lines)
content = pattern.sub(replacement, content)

with open('$INPUT_CONF', 'w') as f:
    f.write(content)
EOF

    notify-send "Hyprland" "Device $device_name: $([ "$new_status" = "1" ] && echo 'Enabled' || echo 'Disabled')"
}

# Toggle both devices
toggle_device "at-translated-set-2-keyboard"
toggle_device "tpps/2-elan-trackpoint"

# Reload Hyprland
hyprctl reload
