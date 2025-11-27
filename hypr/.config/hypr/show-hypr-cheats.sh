#!/usr/bin/env bash
CHEAT="${HOME}/.config/hypr/hypr_shortcuts.txt"
GEN="${HOME}/.config/hypr/generate-hypr-cheats.sh"

# Сначала обновим шпаргалку
if [ -x "$GEN" ]; then
  "$GEN"
fi

if [ ! -f "$CHEAT" ]; then
  echo "Cheats not found: $CHEAT" >&2
  exit 1
fi

# Предпочтительно — открыть в терминале (kitty/foot/alacritty)
if command -v kitty >/dev/null 2>&1; then
  # открываем в kitty; hypr можно настроить, чтобы окна с титулом "HyprCheats" были флотирующими
  kitty --title "HyprCheats" sh -c "less -R '$CHEAT'"
  exit 0
fi

if command -v foot >/dev/null 2>&1; then
  foot -e less "$CHEAT"
  exit 0
fi

if command -v alacritty >/dev/null 2>&1; then
  alacritty -e less "$CHEAT"
  exit 0
fi

# fallback: скопировать в буфер и показать уведомление (понадобится wl-clipboard и mako/notify-send)
if command -v wl-copy >/dev/null 2>&1; then
  wl-copy <"$CHEAT"
  if command -v notify-send >/dev/null 2>&1; then
    notify-send "Hypr cheats" "Скопировано в буфер. Вставьте где нужно (Ctrl+V)."
  else
    echo "Cheats copied to clipboard"
  fi
  exit 0
fi

# последний fallback — вывести в dunst/mako через notify-send (уведомления могут быть обрезаны)
if command -v notify-send >/dev/null 2>&1; then
  notify-send "Hypr cheats" "$(head -n 20 "$CHEAT")"
  exit 0
fi

# если ничего нет — просто печатаем в stdout
cat "$CHEAT"
