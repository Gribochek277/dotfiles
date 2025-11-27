#!/usr/bin/env bash
CONF="${HOME}/.config/hypr/hyprland.conf"
OUT="${HOME}/.config/hypr/hypr_shortcuts.txt"
mkdir -p "$(dirname "$OUT")"

if [ ! -f "$CONF" ]; then
  echo "Hypr config not found: $CONF" >&2
  exit 1
fi

# Парсим: берём строки с "bind" в начале (с учётом пробелов), убираем комментарии, нормализуем запятые
grep -nE '^[[:space:]]*bind' "$CONF" |
  sed -E 's/[[:space:]]*#.*$//' |
  sed -E 's/^[[:space:]]*bind[[:space:]]*=[[:space:]]*//' |
  awk -F',' '
    {
      # trim fields
      for(i=1;i<=NF;i++){ gsub(/^[ \t]+|[ \t]+$/,"",$i) }
      # first one or two fields — клавиши (иногда мод,иногда мод+модификатор)
      keys = $1
      # если второй токен похож не на действие (например KEY вместо action), включим его в keys
      # но проще: если $2 ~ /exec|move|spawn|…/ тогда rest starts from $2, else include $2 in keys
      rest=""
      if (tolower($2) ~ /exec|move|mover|resize|toggle|workspace|splith|splitv|focus|kill|layout|map/ ) {
        for(i=2;i<=NF;i++){ rest = rest (i==2? "" : ", ") $i }
      } else {
        keys = keys ", " $2
        for(i=3;i<=NF;i++){ rest = rest (i==3? "" : ", ") $i }
      }
      # clean up rest
      gsub(/^[ \t]+|[ \t]+$/,"",rest)
      print keys " -> " rest
    }' \
    >"$OUT"

# Human header
{
  echo "Hyprland shortcuts (generated): $(date '+%Y-%m-%d %H:%M:%S')"
  echo "Source: $CONF"
  echo "----------------------------------------"
  cat "$OUT"
} >"${OUT}.tmp" && mv "${OUT}.tmp" "$OUT"

echo "Saved -> $OUT"
