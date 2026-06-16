# Hyprland Key Hold Detection - Complete Reference

## Overview

This document provides comprehensive information about implementing key hold detection in the Hyprland Wayland environment, including audio recording capabilities during key presses.

## Available Tools

### 1. wev (Wayland Event Viewer)

**Location:** `/usr/bin/wev`
**Source:** https://git.sr.ht/~sircmpwn/wev
**Status:** Installed and available

wev is the primary tool for monitoring Wayland events including keyboard input. It displays events in real-time with timestamps.

#### Basic Commands:
```bash
# Monitor all keyboard events
wev -f wl_keyboard:key

# Monitor all events
wev

# Monitor specific interface
wev -f wl_keyboard

# Output format: wl_keyboard@XX.key(timestamp, key, state, unicode)
# State: 0 = pressed, 1 = released
```

#### Sample Output:
```
wl_keyboard@29.key(2852004, 15, 231, 0)
```
- `2852004`: Timestamp in milliseconds
- `15`: Key code (scancode)
- `231`: Key code (keycode)
- `0`: State (0=pressed, 1=released)

### 2. evtest (Input Event Tool)

**Location:** `/usr/bin/evtest`
**Status:** Installed and available

Direct kernel input event monitoring.

#### Basic Commands:
```bash
# List devices
sudo evtest

# Monitor specific device
sudo evtest /dev/input/event3

# Output format includes EV_KEY events with timestamp
```

### 3. libinput

**Status:** Not installed on system

Alternative input library for monitoring events.

#### Basic Commands:
```bash
# List devices
libinput list-devices

# Monitor events
libinput debug-events
```

### 4. Python evdev

**Status:** Not installed

Python bindings for Linux input devices. Provides more precise timing and better integration.

#### Installation:
```bash
pip install evdev
```

## Key Hold Detection Methods

### Method 1: Using wev (Shell Script)

The most portable method using standard Hyprland tools.

#### Event Flow:
1. Key press event received (`state = 0`)
2. Record timestamp
3. Key release event received (`state = 1`)
4. Calculate duration and trigger action

#### Parsing wev Output:
```bash
# Extract fields from wev output
if [[ $line =~ ^wl_keyboard.*key\(([0-9]+),\ *([0-9]+),\ *([0-9]+),\ *([0-9]+)\) ]]; then
    TIME_MS="${BASH_REMATCH[1]}"  # Timestamp
    KEY="${BASH_REMATCH[2]}"       # Scancode
    STATE="${BASH_REMATCH[3]}"     # 0=pressed, 1=released
    UNICODE="${BASH_REMATCH[4]}"   # Unicode (if available)
fi
```

### Method 2: Using Python evdev

More robust implementation with better timing precision.

#### Event Loop:
```python
for event in device.read_loop():
    if event.type == evdev.ecodes.EV_KEY:
        key_event = evdev.categorize(event)
        if key_event.keystate == 0:  # Pressed
            self.press_time = time.time()
        elif key_event.keystate == 1:  # Released
            duration = time.time() - self.press_time
```

### Method 3: Direct /dev/input/event Access

Low-level access to input events.

#### Reading Events:
```bash
# Read binary events from input device
sudo cat /dev/input/event3
```

## Audio Recording During Key Hold

### Tools Comparison

| Tool | Format |优点 |缺点 |
|------|--------|-----|-----|
| arecord (ALSA) | WAV | Low latency, direct | Large files |
| ffmpeg | MP3/WAV/OGG | Compression, format options | Slightly higher latency |
| pactl (PipeWire) | WAV | Native PipeWire | Less common |

### Using arecord (ALSA)

```bash
# Record with arecord
arecord -D default -f cd -t wav output.wav

# Stop recording
kill -TERM $PID

# Options:
# -D device: Audio device (default, hw:0, pulse, etc.)
# -f format: cd (44.1kHz, 16-bit, stereo)
# -t type: wav, raw
# -d duration: Record duration in seconds
```

### Using ffmpeg

```bash
# Record with ffmpeg
ffmpeg -f alsa -i default -t 0:0:0 -y output.mp3

# Options:
# -f alsa: Input format
# -i input: Audio device
# -t 0:0:0: No time limit
# -y: Overwrite output
```

### Using pactl (PipeWire)

```bash
# Record with pactl
pactl record --file-format=wav output.wav

# Cancel recording
pactl cancel-record $ID
```

## Example Scripts

### 1. audio-hold-record.sh

Records audio only while key is held.

**Usage:**
```bash
~/.config/hypr/scripts/audio-hold-record.sh
```

**Configuration:**
```bash
KEY_CODE=231          # Key to listen for
AUDIO_DEVICE="default" # Audio device
OUTPUT_DIR="$HOME/Music/audio_recordings"
```

### 2. key-hold-detect.sh

Detects hold duration and triggers different actions.

**Features:**
- TAP: < 200ms (short press)
- HELD: 200ms - 1000ms (medium hold)
- LONG PRESS: > 1000ms (long hold)

**Configuration:**
```bash
KEY_CODE=231
PRESS_THRESHOLD_MS=200    # Minimum for "held"
LONG_PRESS_MS=1000        # Minimum for "long press"
```

### 3. key-hold-python.py

Python-based detection with evdev.

**Features:**
- Precise timing using time.time()
- Multiple output formats
- Duration-based actions

**Prerequisites:**
```bash
pip install evdev
```

## Integration with Hyprland

### Method 1: Direct Key Binding

Add to `~/.config/hypr/config/keybinds/*.conf`:

```bash
# Bind key to script execution
bind = , 231, exec, ~/.config/hypr/scripts/audio-hold-record.sh
```

### Method 2: Modifier + Key

```bash
# Use main modifier + key
bind = $mainMod, R, exec, ~/.config/hypr/scripts/key-hold-detect.sh

# Or with Ctrl
bind = CTRL, F12, exec, ~/.config/hypr/scripts/ffmpeg-audio-record.sh
```

### Method 3: Key Combination with Modifiers

```bash
# Super + key
bind = SUPER, K, exec, ~/.config/hypr/scripts/key-hold-python.py

# Ctrl + Alt + key
bind = ctrl|alt, K, exec, ~/.config/hypr/scripts/key-hold-detect.sh
```

## Finding Key Codes

### Method 1: Using wev
```bash
wev -f wl_keyboard:key
```

### Method 2: Using evtest
```bash
sudo evtest /dev/input/event3
```

### Method 3: Using Script
```bash
~/.config/hypr/scripts/find-keycode.sh
```

### Method 4: Python evdev
```python
import evdev
for device in evdev.list_devices():
    dev = evdev.InputDevice(device)
    print(f"{dev}: {dev.name}")
    if 'keyboard' in dev.name.lower():
        print(f"  Key codes: {evdev.ecodes.KEY}")
```

## Common Key Codes

| Key | Code | Notes |
|-----|------|-------|
| Space | 231 | Default |
| Enter | 28 | Main/Num |
| ESC | 1 | Escape |
| Shift L | 42 | Left Shift |
| Shift R | 54 | Right Shift |
| Ctrl L | 29 | Left Ctrl |
| Ctrl R | 97 | Right Ctrl |
| Alt L | 56 | Left Alt |
| Alt R | 100 | Right Alt |
| Super L | 133 | Windows Key |
| Super R | 134 | Windows Key |
| F1 | 59 | Function |
| F12 | 70 | Function |
| Print | 158 | Print Screen |

## Duration-Based Actions

### Implementation Pattern:
```bash
HOLD_DURATION=$((release_time - press_time))

if [ "$HOLD_DURATION" -gt "$LONG_PRESS_MS" ]; then
    trigger_long_press_action
elif [ "$HOLD_DURATION" -gt "$PRESS_THRESHOLD_MS" ]; then
    trigger_hold_action
else
    trigger_tap_action
fi
```

### Use Cases:
- **TAP (< 200ms):** Quick action (copy, save)
- **HELD (200ms-1s):** Continuous action (volume up while held)
- **LONG PRESS (> 1s):** Special action (delete, save as)

## Troubleshooting

### Permission Denied
```bash
# Add user to input group
sudo usermod -a -G input $USER
# Log out and back in
```

### wev Not Showing Events
1. Check Wayland session: `echo $WAYLAND_DISPLAY`
2. Try with explicit display: `WAYLAND_DISPLAY=wayland-1 wev`
3. Ensure Hyprland is running

### Audio Recording Issues
1. Check devices: `arecord -l`
2. Test recording: `arecord -D default -f cd -t wav test.wav`
3. Verify audio system: `pulseaudio --check` or `pw-cli list-objects`

### Python evdev Errors
1. Install: `pip install evdev`
2. Check device path: `ls /dev/input/event*`
3. Test installation: `python3 -c "import evdev; print(evdev.list_devices())"`

## Complete Working Example

```bash
#!/bin/bash
# Key hold detection with audio recording

KEY_CODE=231
AUDIO_DEVICE="default"
OUTPUT_DIR="$HOME/Music/recordings"
mkdir -p "$OUTPUT_DIR"

RECORDING_PID=0

wev -f wl_keyboard:key 2>/dev/null | while IFS= read -r line; do
    if [[ $line =~ ^wl_keyboard.*key\(([0-9]+),\ *([0-9]+),\ *([0-9]+),\ *([0-9]+)\) ]]; then
        TIME_MS="${BASH_REMATCH[1]}"
        KEY="${BASH_REMATCH[2]}"
        STATE="${BASH_REMATCH[3]}"
        
        if [ "$KEY" -eq "$KEY_CODE" ]; then
            if [ "$STATE" -eq 0 ]; then
                # Key pressed
                RECORDING_FILE="$OUTPUT_DIR/audio_$(date +%s).wav"
                arecord -D "$AUDIO_DEVICE" -f cd -t wav "$RECORDING_FILE" &
                RECORDING_PID=$!
            elif [ "$STATE" -eq 1 ]; then
                # Key released
                if [ "$RECORDING_PID" -gt 0 ]; then
                    kill -TERM "$RECORDING_PID"
                    wait "$RECORDING_PID"
                    RECORDING_PID=0
                    echo "Saved: $RECORDING_FILE"
                fi
            fi
        fi
    fi
done
```

## Best Practices

1. **Always use absolute paths** in Hyprland config
2. **Make scripts executable** with `chmod +x`
3. **Test with wev first** to verify key codes
4. **Use timestamps** for unique filenames
5. **Handle cleanup** properly to avoid zombie processes
6. **Log errors** to debug issues
7. **Consider input group permissions** for direct input access

## Resources

- Hyprland Wiki: https://wiki.hypr.land/
- wev Source: https://git.sr.ht/~sircmpwn/wev
- ALSA Documentation: https://www.alsa-project.org/
- PipeWire Docs: https://pipewire.org/
- evdev Python: https://python-evdev.readthedocs.io/
