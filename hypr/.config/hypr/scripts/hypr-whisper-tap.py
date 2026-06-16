#!/usr/bin/env python3
"""
Hyprland Whisper Dictation - Tap-to-Record Pattern
Usage: Tap $mod + D to record, tap again to transcribe and insert text
"""

import sys
import os

# Add venv to path
venv_path = os.path.expanduser("~/.venv/evdev")
sys.path.insert(0, venv_path)

import evdev
from evdev import InputDevice, categorize, ecodes
import time
import subprocess
import os
import sys
from threading import Event, Thread

# Configuration
KEY_CODE = 133  # Super_L
TAP_THRESHOLD = 0.1  # 100ms
MODEL_PATH = os.path.expanduser("~/push_to_talk/whisper.cpp/models/ggml-base.bin")
AUDIO_DEVICE = "default"
MAX_RECORDING_SECONDS = 60
TEMP_AUDIO = "/tmp/dictation_audio.wav"
TEMP_TEXT = "/tmp/dictation_text.txt"
OUTPUT_DIR = "/tmp/whisper_dictation"

# State
RECORDING = False
RECORDING_PID = 0
PRESS_TIME = None
KEYBOARD_DEVICE = None


class TapDetector:
    def __init__(self, tap_threshold=TAP_THRESHOLD):
        self.tap_threshold = tap_threshold
        self.running = Event()

    def find_keyboard_device(self):
        """Auto-detect keyboard device"""
        for path in evdev.list_devices():
            try:
                dev = InputDevice(path)
                if "keyboard" in dev.name.lower() and "mouse" not in dev.name.lower():
                    return path
            except:
                continue
        return None

    def tap_callback(self, key_code, duration):
        """Called when tap is detected"""
        global RECORDING, RECORDING_PID, PRESS_TIME

        if not RECORDING:
            # Start recording
            RECORDING = True
            PRESS_TIME = time.time()
            notify("🎤 Recording started", "Hold to speak", "normal")
            start_recording()
        else:
            # Stop recording
            RECORDING = False
            notify("⏹️ Recording stopped", "Processing...", "normal")
            stop_recording()

    def hold_callback(self, key_code):
        """Called when key is held (ignored)"""
        pass


def notify(title, message, urgency="normal"):
    """Send notification"""
    try:
        subprocess.run(["notify-send", "-u", urgency, title, message], check=False)
    except:
        pass


def start_recording():
    """Start audio recording with ffmpeg"""
    global RECORDING_PID

    output_dir = os.path.expanduser(OUTPUT_DIR)
    os.makedirs(output_dir, exist_ok=True)

    filename = os.path.join(output_dir, f"audio_{int(time.time())}.wav")

    cmd = [
        "ffmpeg",
        "-f",
        "alsa",
        "-i",
        AUDIO_DEVICE,
        "-t",
        str(MAX_RECORDING_SECONDS),
        "-y",
        filename,
    ]

    try:
        RECORDING_PID = subprocess.Popen(cmd)
        print(f"Recording started: {filename}")
    except Exception as e:
        print(f"Failed to start recording: {e}")
        notify("❌ Error", "Failed to start recording", "critical")


def stop_recording():
    """Stop recording, transcribe and insert text"""
    global RECORDING_PID

    if RECORDING_PID:
        RECORDING_PID.terminate()
        RECORDING_PID.wait()
        RECORDING_PID = 0

    filename = os.path.join(
        os.path.expanduser(OUTPUT_DIR), f"audio_{int(time.time())}.wav"
    )

    if os.path.exists(filename):
        file_size = os.path.getsize(filename)

        if file_size > 1000:
            transcribe_audio(filename)
        else:
            notify("🔇 No speech detected", "Try again", "normal")
            print("Audio file too small, skipping")
    else:
        print(f"Recording file not found: {filename}")


def transcribe_audio(audio_file):
    """Transcribe audio using whisper.cpp"""
    global TEMP_TEXT

    cmd = [
        os.path.expanduser("~/push_to_talk/whisper.cpp/build/bin/whisper-cli"),
        "-m",
        MODEL_PATH,
        "-f",
        audio_file,
        "-otxt",
        "-l",
        "auto",
        "-np",
        "> /dev/null 2>&1",
    ]

    try:
        subprocess.run(cmd, shell=True, check=True)
        print(f"Transcription output: {TEMP_TEXT}")

        if os.path.exists(TEMP_TEXT):
            with open(TEMP_TEXT, "r", encoding="utf-8") as f:
                text = f.read().strip()

            if text:
                notify("✅ Transcription complete", text, "normal")
                insert_text(text)
                print(f"Inserted: {text}")
            else:
                notify("🔇 No speech detected", "Try again", "normal")
                print("Empty transcription")
        else:
            notify("❌ Transcription failed", "Check logs", "normal")
            print("Transcription file not created")
    except Exception as e:
        print(f"Transcription failed: {e}")
        notify("❌ Transcription failed", str(e), "critical")


def insert_text(text):
    """Insert text using wl-copy"""
    try:
        process = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE, text=True)
        process.communicate(input=text)
    except Exception as e:
        print(f"Failed to insert text: {e}")


def main():
    global KEYBOARD_DEVICE, RECORDING_PID

    print("=" * 50)
    print("Hyprland Whisper Dictation")
    print("=" * 50)
    print(f"Key code: {KEY_CODE}")
    print(f"Tap threshold: {TAP_THRESHOLD}s")
    print(f"Press 'q' or Ctrl+C to quit")
    print("=" * 50)

    # Find keyboard device
    KEYBOARD_DEVICE = TapDetector().find_keyboard_device()

    if not KEYBOARD_DEVICE:
        print("ERROR: No keyboard device found!")
        sys.exit(1)

    print(f"Using keyboard device: {KEYBOARD_DEVICE}")
    detector = TapDetector(TAP_THRESHOLD)
    detector.tap_callback = detector.tap_callback

    try:
        device = InputDevice(KEYBOARD_DEVICE)

        for event in device.read_loop():
            if detector.running.is_set():
                break

            if event.type == ecodes.EV_KEY:
                key_event = categorize(event)

                if key_event.value == 1:  # KEY_PRESS
                    handle_key_press(key_event.code)

                elif key_event.value == 0:  # KEY_RELEASE
                    handle_key_release()

    except KeyboardInterrupt:
        print("\nStopping...")
    finally:
        if RECORDING_PID:
            RECORDING_PID.terminate()
            RECORDING_PID.wait()
        print("Stopped")


def handle_key_press(key_code):
    """Handle key press event"""
    global PRESS_TIME

    if key_code == KEY_CODE:
        PRESS_TIME = time.time()


def handle_key_release():
    """Handle key release event"""
    global PRESS_TIME, RECORDING

    if PRESS_TIME is None:
        return

    duration = time.time() - PRESS_TIME
    PRESS_TIME = None

    if duration < TAP_THRESHOLD:
        print(f"Tap detected: {duration * 1000:.0f}ms")
        TapDetector().tap_callback(KEY_CODE, duration)


if __name__ == "__main__":
    main()
