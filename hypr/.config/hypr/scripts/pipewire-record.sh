#!/bin/bash
# ~/.config/hypr/scripts/pipewire-record.sh
# Audio recording using pactl (PipeWire/PulseAudio) with key hold detection

set -e

# Configuration
KEY_CODE=231
AUDIO_DEVICE="default"
OUTPUT_DIR="$HOME/Music/pipewire_recordings"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$OUTPUT_DIR"

# Variables
RECORDING_ID=0

# Cleanup function
cleanup() {
    if [ "$RECORDING_ID" -gt 0 ]; then
        pactl cancel-record "$RECORDING_ID" 2>/dev/null || true
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

echo "=== PipeWire Audio Recorder ==="
echo "Key code: $KEY_CODE"
echo "Output: $OUTPUT_DIR"
echo "Hold key to record, release to stop."
echo "Press Ctrl+C to exit."
echo "==============================="

# Start wev and process events
wev -f wl_keyboard:key 2>/dev/null | while IFS= read -r line; do
    if [[ $line =~ ^wl_keyboard.*key\(([0-9]+),\ *([0-9]+),\ *([0-9]+),\ *([0-9]+)\) ]]; then
        TIME_MS="${BASH_REMATCH[1]}"
        KEY="${BASH_REMATCH[2]}"
        STATE="${BASH_REMATCH[3]}"
        
        if [ "$KEY" -eq "$KEY_CODE" ]; then
            if [ "$STATE" -eq 0 ]; then
                # Key pressed - start pactl recording
                RECORDING_FILE="$OUTPUT_DIR/audio_${TIMESTAMP}_$(date +%s).wav"
                pactl record --file-format=wav "$RECORDING_FILE" 2>/dev/null &
                RECORDING_ID=$!
                echo "[$(date +%H:%M:%S)] PipeWire recording started (ID: $RECORDING_ID)"
                
            elif [ "$STATE" -eq 1 ]; then
                # Key released - stop pactl recording
                if [ "$RECORDING_ID" -gt 0 ]; then
                    pactl cancel-record "$RECORDING_ID" 2>/dev/null || true
                    wait "$RECORDING_ID" 2>/dev/null || true
                    RECORDING_ID=0
                    
                    if [ -f "$RECORDING_FILE" ]; then
                        FILE_SIZE=$(stat -c%s "$RECORDING_FILE" 2>/dev/null || echo "0")
                        echo "[$(date +%H:%M:%S)] Recording saved: $RECORDING_FILE ($FILE_SIZE bytes)"
                    fi
                fi
            fi
        fi
    fi
done
