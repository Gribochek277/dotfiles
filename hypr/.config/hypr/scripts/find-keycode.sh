#!/bin/bash
# ~/.config/hypr/scripts/find-keycode.sh
# Helper script to find key codes using wev

echo "=== Key Code Finder ==="
echo "Press keys to see their codes"
echo "Press Ctrl+C to exit"
echo "======================"

echo ""
echo "Waiting for key events..."

wev -f wl_keyboard:key 2>/dev/null | while IFS= read -r line; do
    # Parse: wl_keyboard@XX.key(timestamp, key, state, unicode)
    if [[ $line =~ ^wl_keyboard.*key\(([0-9]+),\ *([0-9]+),\ *([0-9]+),\ *([0-9]+)\) ]]; then
        TIME_MS="${BASH_REMATCH[1]}"
        KEY="${BASH_REMATCH[2]}"
        STATE="${BASH_REMATCH[3]}"
        
        if [ "$STATE" -eq 0 ]; then
            echo "Key pressed: code=$KEY (hex: $(printf '0x%02x' $KEY))"
        fi
    fi
done
