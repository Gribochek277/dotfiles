# Key Hold Detection Scripts for Hyprland

This directory contains scripts for detecting key hold duration and triggering actions.

## Available Scripts

### 1. `find-keycode.sh`
Finds the key code for any key you press.

**Usage:**
```bash
~/.config/hypr/scripts/find-keycode.sh
```
Press keys to see their codes. Press Ctrl+C to exit.

### 2. `audio-hold-record.sh`
Records audio only while a key is held down.

**Features:**
- Records to `$HOME/Music/audio_recordings/`
- Timestamp-based filenames
- Automatic cleanup

**Usage:**
1. Find your key code: `~/.config/hypr/scripts/find-keycode.sh`
2. Edit the script to set `KEY_CODE`
3. Run: `~/.config/hypr/scripts/audio-hold-record.sh`

**Integration with Hyprland:**
Add to `~/.config/hypr/config/keybinds/main.conf`:
```bash
bind = , KEYCODE, exec, ~/.config/hypr/scripts/audio-hold-record.sh
```

### 3. `key-hold-detect.sh`
Detects key hold duration and triggers different actions based on hold time.

**Features:**
- TAP: < 200ms - Quick press action
- HELD: 200ms - 1000ms - Hold action
- LONG PRESS: > 1000ms - Long press action

**Usage:**
1. Edit script to set `KEY_CODE`, `PRESS_THRESHOLD_MS`, `LONG_PRESS_MS`
2. Customize action functions
3. Run: `~/.config/hypr/scripts/key-hold-detect.sh`

### 4. `key-hold-python.py`
Python-based key hold detection using evdev library.

**Features:**
- More precise timing
- Multiple recording formats
- Duration-based actions

**Prerequisites:**
```bash
pip install evdev
```

**Usage:**
1. Edit script to set `KEY_CODE` and `INPUT_DEVICE`
2. Run: `~/.config/hypr/scripts/key-hold-python.py`

### 5. `ffmpeg-audio-record.sh`
Records audio using ffmpeg instead of arecord.

**Features:**
- MP3 output (compressed)
- Configurable bitrates

### 6. `pipewire-record.sh`
Records using PipeWire/PulseAudio.

**Features:**
- Native PipeWire support
- Uses `pactl` commands

## Configuration

### Finding Key Codes

Use one of these methods:

1. **wev method:**
   ```bash
   wev -f wl_keyboard:key
   ```

2. **evtest method:**
   ```bash
   sudo evtest /dev/input/event3
   ```

3. **Script method:**
   ```bash
   ~/.config/hypr/scripts/find-keycode.sh
   ```

### Common Key Codes

| Key | Code | Notes |
|-----|------|-------|
| Space | 231 | Default in scripts |
| Enter | 28 | Numpad/Enter key |
| ESC | 1 | Escape key |
| Shift | 42/54 | Left/Right |
| Ctrl | 29/97 | Left/Right |
| Alt | 56/100 | Left/Right |
| F1-F12 | 59-70 | Function keys |

## Integration with Hyprland

### Method 1: Direct Key Binding

Add to `~/.config/hypr/config/keybinds/*.conf`:

```bash
# Record with Space key
bind = , 231, exec, ~/.config/hypr/scripts/audio-hold-record.sh

# Key hold detection with custom key
bind = , 158, exec, ~/.config/hypr/scripts/key-hold-detect.sh
```

### Method 2: Modifier + Key

```bash
# Use main modifier + key
bind = $mainMod, R, exec, ~/.config/hypr/scripts/audio-hold-record.sh

# Or with Ctrl
bind = CTRL, F12, exec, ~/.config/hypr/scripts/key-hold-detect.sh
```

## Customization

### Adjusting Thresholds

Edit the script and modify:

```bash
PRESS_THRESHOLD_MS=200    # Minimum hold for "held" (ms)
LONG_PRESS_MS=1000        # Minimum hold for "long press" (ms)
```

### Changing Audio Device

Edit the script and modify:

```bash
AUDIO_DEVICE="default"    # Or "hw:0,0", "pulse", etc.
```

### Changing Output Directory

Edit the script and modify:

```bash
OUTPUT_DIR="$HOME/Music/audio_recordings"
```

## Troubleshooting

### "Permission denied" on /dev/input/eventX

```bash
sudo usermod -a -G input $USER
# Log out and back in
```

### wev not showing events

1. Ensure you're in a Wayland session
2. Check `WAYLAND_DISPLAY` environment variable
3. Try: `WAYLAND_DISPLAY=wayland-1 wev`

### Audio recording issues

1. Check available devices: `arecord -l`
2. Test with: `arecord -D default -f cd -t wav test.wav`
3. Verify audio system is running: `pulseaudio --check` or `pw-cli list-objects`

### Python script errors

```bash
# Install evdev
pip install evdev

# Check device path
ls /dev/input/event*

# Test evdev
python3 -c "import evdev; print(evdev.list_devices())"
```

## Examples

### Voice Memo Recorder

```bash
# Add to Hyprland config:
bind = , 231, exec, ~/.config/hypr/scripts/audio-hold-record.sh
```
Hold Space to record voice memos.

### Multi-Function Key

```bash
# Script: key-hold-detect.sh
# - Short tap: Copy
# - Hold: Paste
# - Long press: Save

# Add to Hyprland config:
bind = $mainMod, F1, exec, ~/.config/hypr/scripts/key-hold-detect.sh
```

## See Also

- Hyprland documentation: https://wiki.hyprland.org/
- wev source: https://git.sr.ht/~sircmpwn/wev
- ALSA documentation: https://www.alsa-project.org/
- PipeWire documentation: https://pipewire.org/
