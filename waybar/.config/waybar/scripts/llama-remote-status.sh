#!/usr/bin/env bash

CONFIG_FILE="${LLAMA_REMOTE_CONFIG:-$HOME/.config/waybar/scripts/llama-remote-config.json}"

PORT=$(jq -r '.port // 8080' "$CONFIG_FILE" 2>/dev/null || echo 8080)
HOST=$(jq -r '.host // "127.0.0.1"' "$CONFIG_FILE" 2>/dev/null || echo "127.0.0.1")
BASE_URL="http://${HOST}:${PORT}"

ICON_OFF=$'\uf5dc'
ICON_ON=$'\uf111'
ICON_SLEEP=$'\uf186'

output_json() {
    jq -nc --arg text "$1" --arg tooltip "$2" --arg class "$3" \
        '{text: $text, tooltip: $tooltip, class: $class}'
}

health=$(curl -s --max-time 2 "${BASE_URL}/health" 2>/dev/null || echo "")

if [ -z "$health" ]; then
    output_json "${ICON_OFF} Remote" "Remote server offline"$'\n'"${BASE_URL}" "remote-offline"
    exit 0
fi

status=$(echo "$health" | jq -r '.status // ""' 2>/dev/null || echo "")
if [ "$status" != "ok" ]; then
    output_json "${ICON_OFF} Remote" "Remote server loading..."$'\n'"${BASE_URL}" "remote-offline"
    exit 0
fi

props=$(curl -s --max-time 2 "${BASE_URL}/props" 2>/dev/null || echo "{}")
model_alias=$(echo "$props" | jq -r '.model_alias // "unknown"' 2>/dev/null)
n_ctx=$(echo "$props" | jq -r '.default_generation_settings.n_ctx // "?"' 2>/dev/null)
total_slots=$(echo "$props" | jq -r '.total_slots // 1' 2>/dev/null)
is_sleeping=$(echo "$props" | jq -r '.is_sleeping // false' 2>/dev/null)
build_info=$(echo "$props" | jq -r '.build_info // "?"' 2>/dev/null)

short_model=$(basename "$model_alias" 2>/dev/null | sed 's/\.gguf$//' | cut -c1-10 || echo "$model_alias" | cut -c1-10)

if [ "$is_sleeping" = "true" ]; then
    text="${ICON_SLEEP} ${short_model}"
    class="remote-sleeping"
else
    text="${ICON_ON} ${short_model}"
    class="remote-online"
fi

tooltip="Model: ${model_alias}"
tooltip+=$'\n'"Context: ${n_ctx} tokens"
tooltip+=$'\n'"Slots: ${total_slots}"
tooltip+=$'\n'"Sleeping: ${is_sleeping}"
tooltip+=$'\n'"Build: ${build_info}"
tooltip+=$'\n'"URL: ${BASE_URL}"

output_json "$text" "$tooltip" "$class"
