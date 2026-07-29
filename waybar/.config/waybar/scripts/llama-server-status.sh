#!/usr/bin/env bash

CONFIG_FILE="${LLAMA_SERVER_CONFIG:-$HOME/.config/waybar/scripts/llama-server-config.json}"
STATE_FILE="/tmp/llama-server-waybar-state.json"

PORT=$(jq -r '.port // 8080' "$CONFIG_FILE" 2>/dev/null || echo 8080)
HOST=$(jq -r '.host // "127.0.0.1"' "$CONFIG_FILE" 2>/dev/null || echo "127.0.0.1")
PID_FILE=$(jq -r '.pid_file // "/tmp/llama-server.pid"' "$CONFIG_FILE" 2>/dev/null || echo "/tmp/llama-server.pid")
BASE_URL="http://${HOST}:${PORT}"

ICON_STOPPED=$'\uf5dc'
ICON_LOADING=$'\uf252'
ICON_IDLE=$'\uf111'
ICON_PREFILL=$'\uf0ab'
ICON_GENERATING=$'\uf0e7'

output_json() {
    jq -nc --arg text "$1" --arg tooltip "$2" --arg class "$3" \
        '{text: $text, tooltip: $tooltip, class: $class}'
}

if [ ! -f "$PID_FILE" ]; then
    output_json "${ICON_STOPPED} Local" "Server not running"$'\n'"Click to open menu" "stopped"
    exit 0
fi

PID=$(cat "$PID_FILE" 2>/dev/null)
if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
    rm -f "$PID_FILE"
    output_json "${ICON_STOPPED} Local" "Server not running"$'\n'"Click to open menu" "stopped"
    exit 0
fi

health=$(curl -s --max-time 1 "${BASE_URL}/health" 2>/dev/null || echo "")

if [ -z "$health" ]; then
    if pgrep -x "llama-server" >/dev/null 2>&1; then
        output_json "${ICON_LOADING} loading..." "Model is loading..." "loading"
    else
        rm -f "$PID_FILE"
        output_json "${ICON_STOPPED} Local" "Server not running"$'\n'"Click to open menu" "stopped"
    fi
    exit 0
fi

status=$(echo "$health" | jq -r '.status // ""' 2>/dev/null || echo "")
if [ "$status" != "ok" ]; then
    output_json "${ICON_LOADING} loading..." "Model is loading..." "loading"
    exit 0
fi

metrics=$(curl -s --max-time 1 "${BASE_URL}/metrics" 2>/dev/null || echo "")

parse_metric() {
    echo "$metrics" | grep -E "^llamacpp:$1 " | awk '{print $2}'
}

props=$(curl -s --max-time 1 "${BASE_URL}/props" 2>/dev/null || echo "{}")
model_alias=$(echo "$props" | jq -r '.model_alias // "unknown"' 2>/dev/null)
n_ctx=$(echo "$props" | jq -r '.default_generation_settings.n_ctx // "?"' 2>/dev/null)
total_slots=$(echo "$props" | jq -r '.total_slots // 1' 2>/dev/null)

short_model=$(basename "$model_alias" 2>/dev/null | sed 's/\.gguf$//' | cut -c1-10 || echo "$model_alias" | cut -c1-10)

req_processing=$(parse_metric requests_processing)
req_deferred=$(parse_metric requests_deferred)
prompt_tokens_total=$(parse_metric prompt_tokens_total)
predicted_tokens_total=$(parse_metric tokens_predicted_total)
prompt_tps_avg=$(parse_metric prompt_tokens_seconds)
predicted_tps_avg=$(parse_metric predicted_tokens_seconds)

req_processing=${req_processing:-0}
req_deferred=${req_deferred:-0}
prompt_tokens_total=${prompt_tokens_total:-0}
predicted_tokens_total=${predicted_tokens_total:-0}

now=$(date +%s.%N)

prev_prompt_total=0
prev_n_decoded=0
prev_tps=""
prev_ts=$now
if [ -f "$STATE_FILE" ]; then
    prev_prompt_total=$(jq -r '.prompt_tokens_total // 0' "$STATE_FILE" 2>/dev/null || echo 0)
    prev_n_decoded=$(jq -r '.n_decoded // 0' "$STATE_FILE" 2>/dev/null || echo 0)
    prev_tps=$(jq -r '.last_tps // ""' "$STATE_FILE" 2>/dev/null || echo "")
    prev_ts=$(jq -r '.timestamp // now' "$STATE_FILE" 2>/dev/null || echo "$now")
fi

d_prompt_total=$(awk -v n="$prompt_tokens_total" -v p="$prev_prompt_total" 'BEGIN { d = n - p; if (d < 0) d = 0; print d }')

slots=""
n_decoded=0
n_prompt_processed=0
n_prompt_tokens=0
if [ "$req_processing" -gt 0 ] 2>/dev/null; then
    slots=$(curl -s --max-time 0.5 "${BASE_URL}/slots" 2>/dev/null || echo "")
fi

if [ -n "$slots" ] && [ "$slots" != "" ]; then
    processing_slot=$(echo "$slots" | jq -c '[.[] | select(.is_processing == true)] | .[0] // empty' 2>/dev/null)
    if [ -n "$processing_slot" ] && [ "$processing_slot" != "null" ]; then
        n_prompt_tokens=$(echo "$processing_slot" | jq -r '.n_prompt_tokens // 0' 2>/dev/null || echo 0)
        n_prompt_processed=$(echo "$processing_slot" | jq -r '.n_prompt_tokens_processed // 0' 2>/dev/null || echo 0)
        n_decoded=$(echo "$processing_slot" | jq -r '.next_token[0].n_decoded // 0' 2>/dev/null || echo 0)
    fi
fi

dt=$(awk -v now="$now" -v prev_ts="$prev_ts" 'BEGIN { d = now - prev_ts; if (d < 0.5) d = 0; print d }')

tps=""
if [ "$req_processing" -gt 0 ] 2>/dev/null; then
    if [ "$n_decoded" -gt 0 ] 2>/dev/null; then
        if [ -n "$slots" ]; then
            d_decoded=$(awk -v n="$n_decoded" -v p="$prev_n_decoded" 'BEGIN { d = n - p; if (d < 0) d = 0; print d }')
            tps=""
            if [ "$d_decoded" -gt 0 ] 2>/dev/null && [ "$dt" != "0" ]; then
                tps=$(awk -v d="$d_decoded" -v dt="$dt" 'BEGIN { printf "%.1f", d / dt }')
            fi
            if [ -z "$tps" ] && [ "$predicted_tps_avg" != "0" ] && [ -n "$predicted_tps_avg" ]; then
                tps=$(awk -v t="$predicted_tps_avg" 'BEGIN { printf "%.1f", t }')
            fi
            if [ -z "$tps" ] && [ -n "$prev_tps" ]; then
                tps="$prev_tps"
            fi
        else
            tps=""
            if [ "$predicted_tps_avg" != "0" ] && [ -n "$predicted_tps_avg" ]; then
                tps=$(awk -v t="$predicted_tps_avg" 'BEGIN { printf "%.1f", t }')
            fi
            if [ -z "$tps" ] && [ -n "$prev_tps" ]; then
                tps="$prev_tps"
            fi
        fi
        text="${ICON_GENERATING} ${short_model}"
        [ -n "$tps" ] && text="${text} ${tps} t/s"
        class="generating"
    elif [ "$d_prompt_total" -gt 0 ] 2>/dev/null; then
        tps=""
        if [ "$dt" != "0" ]; then
            tps=$(awk -v d="$d_prompt_total" -v dt="$dt" 'BEGIN { printf "%.1f", d / dt }')
        fi
        if [ -z "$tps" ] && [ "$prompt_tps_avg" != "0" ] && [ -n "$prompt_tps_avg" ]; then
            tps=$(awk -v t="$prompt_tps_avg" 'BEGIN { printf "%.1f", t }')
        fi
        text="${ICON_PREFILL} ${short_model}"
        [ -n "$tps" ] && text="${text} ${tps} t/s"
        class="prefill"
    elif [ "$n_prompt_processed" -gt 0 ] 2>/dev/null && [ "$n_prompt_processed" -lt "$n_prompt_tokens" ] 2>/dev/null; then
        tps=""
        if [ "$prompt_tps_avg" != "0" ] && [ -n "$prompt_tps_avg" ]; then
            tps=$(awk -v t="$prompt_tps_avg" 'BEGIN { printf "%.1f", t }')
        fi
        text="${ICON_PREFILL} ${short_model}"
        [ -n "$tps" ] && text="${text} ${tps} t/s"
        class="prefill"
    else
        text="${ICON_PREFILL} ${short_model} processing..."
        class="prefill"
    fi
else
    text="${ICON_IDLE} ${short_model}"
    class="idle"
fi

state_tps=""
[ -n "$tps" ] && [ "$class" != "idle" ] && state_tps="$tps"
jq -nc \
    --argjson pt "$prompt_tokens_total" \
    --argjson nd "$n_decoded" \
    --argjson ts "$now" \
    --arg tps "$state_tps" \
    '{prompt_tokens_total:$pt, n_decoded:$nd, timestamp:$ts, last_tps:$tps}' > "$STATE_FILE"

tooltip="Model: ${model_alias}"
tooltip+=$'\n'"Context: ${n_ctx} tokens"
tooltip+=$'\n'"Slots: ${req_processing}/${total_slots} active"
if [ "$req_deferred" -gt 0 ] 2>/dev/null; then
    tooltip+=$'\n'"Queued: ${req_deferred}"
fi
if [ "$req_processing" -gt 0 ] 2>/dev/null; then
    if [ "$n_prompt_tokens" -gt 0 ] 2>/dev/null; then
        tooltip+=$'\n'"Prompt: ${n_prompt_processed}/${n_prompt_tokens} processed"
    fi
    if [ "$n_decoded" -gt 0 ] 2>/dev/null; then
        tooltip+=$'\n'"Decoded: ${n_decoded} tokens"
    fi
fi
tooltip+=$'\n'"Total prompt: ${prompt_tokens_total} tokens"
tooltip+=$'\n'"Total generated: ${predicted_tokens_total} tokens"
tooltip+=$'\n'"URL: ${BASE_URL}"

output_json "$text" "$tooltip" "$class"
