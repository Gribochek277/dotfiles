#!/bin/bash
# ~/.config/hypr/scripts/key-hold-detect.sh
# Detects key hold duration and triggers different actions based on hold time

set -e

# Configuration
KEY_CODE=231  # Key to detect (231=Space)
PRESS_THRESHOLD_MS=200  # Minimum hold time to consider "held" (200ms)
LONG_PRESS_MS=1000  # Long press threshold (1000ms)

# Variables to track state
PRESS_TIME=0
HELD=false

# Function to handle key press
handle_press() {
    local key=$1
    local time_ms=$2
    
    if [ "$key" -eq "$KEY_CODE" ]; then
        PRESS_TIME=$time_ms
        HELD=true
        echo "[$(date +%H:%M:%S)] Key $key pressed at $time_ms"
    fi
}

# Function to handle key release
handle_release() {
    local key=$1
    local time_ms=$2
    
    if [ "$key" -eq "$KEY_CODE" ] && [ "$HELD" = true ]; then
        local HOLD_DURATION=$((time_ms - PRESS_TIME))
        HELD=false
        
        echo "[$(date +%H:%M:%S)] Key released after ${HOLD_DURATION}ms"
        
        if [ "$HOLD_DURATION" -gt "$LONG_PRESS_MS" ]; then
            echo "[$(date +%H:%M:%S)] LONG PRESS (${HOLD_DURATION}ms) - triggering long press action"
            trigger_long_press_action "$HOLD_DURATION"
        elif [ "$HOLD_DURATION" -gt "$PRESS_THRESHOLD_MS" ]; then
            echo "[$(date +%H:%M:%S)] HELD (${HOLD_DURATION}ms) - triggering hold action"
            trigger_hold_action "$HOLD_DURATION"
        else
            echo "[$(date +%H:%M:%S)] SHORT TAP (${HOLD_DURATION}ms) - triggering tap action"
            trigger_tap_action "$HOLD_DURATION"
        fi
    fi
}

# Functions to trigger different actions based on hold duration
trigger_tap_action() {
    local duration=$1
    # Add your custom tap action here
    echo "Action: Quick tap (duration: ${duration}ms)"
}

trigger_hold_action() {
    local duration=$1
    # Add your custom hold action here
    echo "Action: Key held (duration: ${duration}ms)"
}

trigger_long_press_action() {
    local duration=$1
    # Add your custom long press action here
    echo "Action: Long press (duration: ${duration}ms)"
}

echo "=== Key Hold Detector ==="
echo "Key code: $KEY_CODE"
echo "Threshold: ${PRESS_THRESHOLD_MS}ms"
echo "Long press: ${LONG_PRESS_MS}ms"
echo "========================"

# Main wev loop
wev -f wl_keyboard:key 2>/dev/null | while IFS= read -r line; do
    # Parse wev output: wl_keyboard@XX.key(timestamp, key, state, unicode)
    if [[ $line =~ ^wl_keyboard.*key\(([0-9]+),\ *([0-9]+),\ *([0-9]+),\ *([0-9]+)\) ]]; then
        local time_ms="${BASH_REMATCH[1]}"
        local key="${BASH_REMATCH[2]}"
        local state="${BASH_REMATCH[3]}"
        
        if [ "$state" -eq 0 ]; then
            handle_press "$key" "$time_ms"
        elif [ "$state" -eq 1 ]; then
            handle_release "$key" "$time_ms"
        fi
    fi
done
