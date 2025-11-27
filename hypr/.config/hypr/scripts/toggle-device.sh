#!/usr/bin/env bash
set -euo pipefail

DEVICE_NAME="$1" # например: tpps/2-elan-trackpoint
HYPRLAND_CONFIG="$HOME/.config/hypr/hyprland.conf"

# Находим номер строки, где встречается точная строка "name = $DEVICE_NAME"
LINE=$(awk -v dev="$DEVICE_NAME" '
  { if (index($0, "name = " dev)) { print NR; exit } }
' "$HYPRLAND_CONFIG" || true)

if [ -z "$LINE" ]; then
  notify-send "Hyprland" "Устройство не найдено: $DEVICE_NAME"
  echo "Device not found: $DEVICE_NAME" >&2
  exit 1
fi

# Читаем текущее значение enabled (строка ниже найденной)
ENABLED_LINE=$((LINE + 1))
CURRENT=$(sed -n "${ENABLED_LINE}p" "$HYPRLAND_CONFIG" | awk '{print $3}' || true)

if [ -z "$CURRENT" ]; then
  notify-send "Hyprland" "Не удалось прочитать enabled для $DEVICE_NAME"
  echo "Failed to read enabled" >&2
  exit 1
fi

# Переключаем
if [ "$CURRENT" -eq 1 ]; then
  NEW=0
  MSG="Отключено: $DEVICE_NAME"
else
  NEW=1
  MSG="Включено: $DEVICE_NAME"
fi

# Заменяем конкретную линию (без проблем с символами в имени)
sed -i "${ENABLED_LINE}s/enabled = .*/enabled = $NEW/" "$HYPRLAND_CONFIG"

# Перезагружаем Hyprland и показываем popup
hyprctl reload
notify-send "Hyprland" "$MSG"
