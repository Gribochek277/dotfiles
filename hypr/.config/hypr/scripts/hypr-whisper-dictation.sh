#!/bin/bash
# ~/.config/hypr/scripts/hypr-whisper-dictation.sh
# Voice dictation system using whisper.cpp + wev + wtype
# Usage: Hold $mainMod + D to record, release to transcribe and insert text

set -e

# Configuration
KEY_CODE=133  # Default: Super (Windows) key code
AUDIO_DEVICE="default"
MODEL_PATH="$HOME/push_to_talk/whisper.cpp/models/ggml-base.bin"
OUTPUT_DIR="/tmp/whisper_dictation"
MAX_RECORDING_SECONDS=60
TEMP_AUDIO="/tmp/dictation_audio.wav"
TEMP_TEXT="/tmp/dictation_text.txt"

mkdir -p "$OUTPUT_DIR"

# Variables to track state
PRESS_TIME=0
RECORDING_PID=0
WEV_PID=0
TRANSCRIPT=""

# Notification function
notify() {
    local message="$1"
    local urgency="${2:-normal}"
    notify-send -u "$urgency" "Dictation" "$message" 2>/dev/null || true
}

cleanup() {
    if [ "$RECORDING_PID" -gt 0 ]; then
        kill -TERM "$RECORDING_PID" 2>/dev/null || true
        wait "$RECORDING_PID" 2>/dev/null || true
    fi
    if [ "$WEV_PID" -gt 0 ]; then
        kill -TERM "$WEV_PID" 2>/dev/null || true
        wait "$WEV_PID" 2>/dev/null || true
    fi
    exit 0
}

trap cleanup SIGINT SIGTERM

echo "=== Hyprland Whisper Dictation ==="
echo "Key code: $KEY_CODE"
echo "Model: $MODEL_PATH"
echo "Hold key to record, release to transcribe."
echo "Press Ctrl+C to exit."
echo "==============================="

# Start wev in background
wev -f wl_keyboard:key >/dev/null 2>&1 &
WEV_PID=$!

# Process events in current shell
while IFS= read -r line; do
    if [[ $line =~ ^wl_keyboard.*key\(([0-9]+),\ *([0-9]+),\ *([0-9]+),\ *([0-9]+)\) ]]; then
        TIME_MS="${BASH_REMATCH[1]}"
        KEY="${BASH_REMATCH[2]}"
        STATE="${BASH_REMATCH[3]}"  # 0=pressed, 1=released

        if [ "$KEY" -eq "$KEY_CODE" ]; then
            if [ "$STATE" -eq 0 ]; then
                # Key pressed - start recording
                PRESS_TIME=$(date +%s)
                RECORDING_FILE="$OUTPUT_DIR/audio_$(date +%s).wav"
                notify "🎤 Recording started" "Hold the key to speak" "normal"
                echo "[$(date +%H:%M:%S)] Recording started..."
                ffmpeg -f alsa -i "$AUDIO_DEVICE" -t "$MAX_RECORDING_SECONDS" -y "$RECORDING_FILE" 2>/dev/null &
                RECORDING_PID=$!

            elif [ "$STATE" -eq 1 ]; then
                # Key released - stop recording and transcribe
                if [ "$RECORDING_PID" -gt 0 ]; then
                    kill -TERM "$RECORDING_PID" 2>/dev/null
                    wait "$RECORDING_PID" 2>/dev/null
                    RECORDING_PID=0

                    if [ -f "$RECORDING_FILE" ]; then
                        FILE_SIZE=$(stat -c%s "$RECORDING_FILE" 2>/dev/null || echo "0")
                        echo "[$(date +%H:%M:%S)] Recording saved: $RECORDING_FILE ($FILE_SIZE bytes)"

                        if [ "$FILE_SIZE" -gt 1000 ]; then
                            notify "⏹️ Recording stopped" "Processing..." "normal"
                            echo "[$(date +%H:%M:%S)] Transcribing..."
                            $HOME/push_to_talk/whisper.cpp/build/bin/whisper-cli \
                                -m "$MODEL_PATH" \
                                -f "$RECORDING_FILE" \
                                -otxt \
                                -l auto \
                                -np \
                                2>/dev/null

                            if [ -f "$TEMP_TEXT" ]; then
                                TRANSCRIPT=$(cat "$TEMP_TEXT" 2>/dev/null | tr -d '\n')
                                echo "[$(date +%H:%M:%S)] Transcribed: $TRANSCRIPT"

                                if [ -n "$TRANSCRIPT" ]; then
                                    notify "✅ Transcription complete" "$TRANSCRIPT" "normal"
                                    echo "[$(date +%H:%M:%S)] Inserting text..."
                                    echo -n "$TRANSCRIPT" | wl-copy
                                    echo "[$(date +%H:%M:%S)] Text copied to clipboard!"
                                else
                                    notify "🔇 No speech detected" "Try again" "normal"
                                    echo "[$(date +%H:%M:%S)] No speech detected"
                                fi
                            else
                                notify "❌ Transcription failed" "Check logs" "normal"
                                echo "[$(date +%H:%M:%S)] Transcription failed"
                            fi
                        else
                            echo "[$(date +%H:%M:%S)] Audio file too small, skipping"
                        fi
                    fi
                fi
            fi
        fi
    fi
done
