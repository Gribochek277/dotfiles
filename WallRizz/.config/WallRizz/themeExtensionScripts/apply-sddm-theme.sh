#!/bin/sh
# WallRizz SDDM theme applicator
# Called by sddm@5hubham5ingh.js via sudo (NOPASSWD)
# Usage: sudo apply-sddm-theme.sh <theme.conf> <wp-src> <wp-dst>
set -e

theme_src="$1"
wp_src="$2"
wp_dst="$3"
theme_dst="/usr/share/sddm/themes/where-is-my-sddm-theme/theme.conf"

# 1. Copy selected wallpaper to /usr/share/backgrounds/ (SDDM-readable)
if [ -n "$wp_src" ] && [ -f "$wp_src" ]; then
  cp -f -- "$wp_src" "$wp_dst"
else
  echo "Warning: wallpaper source not found, skipping wallpaper copy" >&2
fi

# 2. Copy themed config to where-is-my-sddm-theme
if [ -n "$theme_src" ] && [ -f "$theme_src" ]; then
  cp -f -- "$theme_src" "$theme_dst"
else
  echo "Warning: theme.conf not found, skipping theme update" >&2
fi
