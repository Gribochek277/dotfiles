#!/usr/bin/env python3
# ~/.config/hypr/scripts/key-hold-python.py
# Python-based key hold detection with audio recording

import evdev
import time
import os
import subprocess
from datetime import datetime
from pathlib import Path
import signal
import sys

# Configuration
KEY_CODE = evdev.ecodes.KEY_SPACE  # Change to desired key
INPUT_DEVICE = "/dev/input/event3"  # Adjust for your keyboard (find with: ls /dev/input/event*)
AUDIO_DEVICE = "default"
OUTPUT_DIR = "/tmp/audio_recordings"
PRESS_THRESHOLD_MS = 200
LONG_PRESS_MS = 1000

# Ensure output directory exists
Path(OUTPUT_DIR).mkdir(parents=True, exist_ok=True)

class KeyHoldRecorder:
    def __init__(self):
        self.press_time = None
        self.recording_process = None
        self.recording_file = None
        self.key_pressed = False
        
        # Find input device
        try:
            self.device = evdev.InputDevice(INPUT_DEVICE)
            print(f"Using device: {self.device.name}")
            print(f"Listening for key code: {KEY_CODE}")
            print(f"Key name: {evdev.ecodes.KEY[KEY_CODE] if KEY_CODE in evdev.ecodes.KEY else 'unknown'}")
        except FileNotFoundError:
            print(f"Error: Device {INPUT_DEVICE} not found")
            print("Available devices:")
            for dev in Path("/dev/input").glob("event*"):
                try:
                    d = evdev.InputDevice(str(dev))
                    print(f"  {dev}: {d.name}")
                except:
                    pass
            sys.exit(1)

    def start_recording(self):
        """Start audio recording"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        self.recording_file = f"{OUTPUT_DIR}/audio_{timestamp}.wav"
        
        cmd = [
            "arecord",
            "-D", AUDIO_DEVICE,
            "-f", "cd",
            "-t", "wav",
            self.recording_file
        ]
        
        print(f"[{self.get_timestamp()}] Starting recording: {self.recording_file}")
        self.recording_process = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.press_time = time.time()
        self.key_pressed = True

    def stop_recording(self):
        """Stop audio recording and calculate duration"""
        if self.recording_process and self.recording_process.poll() is None:
            duration = round(time.time() - self.press_time, 3) if self.press_time else 0
            
            print(f"[{self.get_timestamp()}] Stopping recording (held for {duration:.3f}s)...")
            self.recording_process.terminate()
            try:
                self.recording_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.recording_process.kill()
                self.recording_process.wait()
            
            self.recording_process = None
            
            if self.recording_file and os.path.exists(self.recording_file):
                file_size = os.path.getsize(self.recording_file)
                duration_ms = int(duration * 1000)
                
                # Determine action based on hold duration
                if duration_ms > LONG_PRESS_MS:
                    print(f"[{self.get_timestamp()}] LONG PRESS - triggering action")
                    self.trigger_long_press_action(duration_ms)
                elif duration_ms > PRESS_THRESHOLD_MS:
                    print(f"[{self.get_timestamp()}] HELD - triggering action")
                    self.trigger_hold_action(duration_ms)
                else:
                    print(f"[{self.get_timestamp()}] TAP - triggering action")
                    self.trigger_tap_action(duration_ms)
                
                print(f"Recording saved: {self.recording_file} ({file_size} bytes)")
            
            self.press_time = None
            self.key_pressed = False
            self.recording_file = None

    def get_timestamp(self):
        """Get formatted timestamp"""
        return datetime.now().strftime("%H:%M:%S")

    def trigger_tap_action(self, duration_ms):
        """Action for short taps (< 200ms)"""
        print(f"  Action: Quick tap ({duration_ms}ms)")

    def trigger_hold_action(self, duration_ms):
        """Action for held keys (200ms - 1000ms)"""
        print(f"  Action: Key held ({duration_ms}ms)")

    def trigger_long_press_action(self, duration_ms):
        """Action for long presses (> 1000ms)"""
        print(f"  Action: Long press ({duration_ms}ms)")

    def run(self):
        """Main event loop"""
        print("Starting key hold detection...")
        print("Press and hold the configured key to record.")
        print("Press Ctrl+C to exit.\n")
        
        try:
            for event in self.device.read_loop():
                if event.type == evdev.ecodes.EV_KEY:
                    key_event = evdev.categorize(event)
                    
                    # Check if it's our target key
                    is_target_key = (
                        hasattr(key_event.keycode, 'code') and key_event.keycode.code == KEY_CODE
                    ) or key_event.scancode == KEY_CODE
                    
                    if is_target_key:
                        # State: 0 = pressed, 1 = released
                        if key_event.keystate == 0 and not self.key_pressed:
                            self.start_recording()
                        elif key_event.keystate == 1 and self.key_pressed:
                            self.stop_recording()
                            
        except KeyboardInterrupt:
            print("\nExiting...")
            self.stop_recording()

def main():
    # Check if evdev is installed
    try:
        import evdev
    except ImportError:
        print("Error: evdev module not installed")
        print("Install with: pip install evdev")
        sys.exit(1)
    
    recorder = KeyHoldRecorder()
    recorder.run()

if __name__ == "__main__":
    main()
