#!/bin/bash

UNIT=home-serhii-Silo.automount
MOUNT=/home/serhii/Silo

if mountpoint -q "$MOUNT" 2>/dev/null; then
  exec pkexec systemctl disable --now "$UNIT"
else
  exec pkexec systemctl enable --now "$UNIT"
fi
