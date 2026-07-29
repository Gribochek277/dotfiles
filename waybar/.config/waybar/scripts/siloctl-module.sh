#!/bin/bash

UNIT=home-serhii-Silo.automount
MOUNT=/home/serhii/Silo

if mountpoint -q "$MOUNT" 2>/dev/null; then
  text=" 󰋊 "
  class="mounted"
  alt="mounted"
  tooltip="Silo NAS: mounted"
else
  text=" 󰋊 "
  class="unmounted"
  alt="unmounted"
  tooltip="Silo NAS: unmounted"
fi

if systemctl is-enabled "$UNIT" &>/dev/null; then
  tooltip="$tooltip • auto on"
else
  tooltip="$tooltip • auto off"
fi

echo "{\"text\": \"$text\", \"alt\": \"$alt\", \"tooltip\": \"$tooltip\", \"class\": \"$class\"}"
