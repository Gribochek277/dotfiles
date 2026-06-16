#!/bin/bash
# ~/.config/hypr/scripts/audio-hold-record.sh
# Records audio only while the specified key is held down
# Usage: Add to Hyprland config with a keybinding

set -e

# Configuration
KEY_CODE=231  # Change to your desired key code (231=Space, 28=Enter, etc.)
AUDIO_DEVICE="default"
OUTPUT_DIR="$HOME/Music/audio_recordings"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

# Variables to track state
PRESS_TIME=0
RECORDING_PID=0
RECORDING_FILE=""

# Cleanup function
cleanup() {
    if [ "$RECORDING_PID" -gt 0 ]; then
        kill -TERM "$RECORDING_PID" 2>/dev/null || true
        wait "$RECORDING_PID" 2>/dev/null || true
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

echo "=== Audio Hold Recorder ==="
echo "Key code: $KEY_CODE"
echo "Output: $OUTPUT_DIR"
echo "Hold key to record, release to stop."
echo "Press Ctrl+C to exit."
echo "==========================="

# Start wev and process events
wev -f wl_keyboard:key 2>/dev/null | while IFS= read -r line; do
    # Parse: wl_keyboard@XX.key(timestamp, key, state, unicode)
    if [[ $line =~ ^wl_keyboard.*key\(([0-9]+),\ *([0-9]+),\ *([0-9]+),\ *([0-9]+)\) ]]; then
        TIME_MS="${BASH_REMATCH[1]}"
        KEY="${BASH_REMATCH[2]}"
        STATE="${BASH_REMATCH[3]}"  # 0=pressed, 1=released
        
        # Check if this is our target key
        if [ "$KEY" -eq "$KEY_CODE" ]; then
            if [ "$STATE" -eq 0 ]; then
                # Key pressed - start recording
                RECORDING_FILE="$OUTPUT_DIR/audio_${TIMESTAMP}_$(date +%s).wav"
                arecord -D "$AUDIO_DEVICE" -f cd -t wav "$RECORDING_FILE" 2>/dev/null &
                RECORDING_PID=$!
                echo "[$(date +%H:%M:%S)] Recording started (PID: $RECORDING_PID)"
                
            elif [ "$STATE" -eq 1 ]; then
                # Key released - stop recording
                if [ "$RECORDING_PID" -gt 0 ]; then
                    kill -TERM "$RECORDING_PID" 2>/dev/null
                    wait "$RECORDING_PID" 2>/dev/null
                    RECORDING_PID=0
                    
                    if [ -f "$RECORDING_FILE" ]; then
                        FILE_SIZE=$(stat -c%s "$RECORDING_FILE" 2>/dev/null || echo "0")
                        echo "[$(date +%H:%M:%S)] Recording saved: $RECORDING_FILE ($FILE_SIZE bytes)"
                    fi
                fi
            fi
        fi
    fi
done
