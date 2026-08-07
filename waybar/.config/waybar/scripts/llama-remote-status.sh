#!/usr/bin/env bash

CONFIG_FILE="${LLAMA_REMOTE_CONFIG:-$HOME/.config/waybar/scripts/llama-remote-config.json}"
STATE_FILE="/tmp/llama-remote-waybar-state.json"

PORT=$(jq -r '.port // 8080' "$CONFIG_FILE" 2>/dev/null || echo 8080)
HOST=$(jq -r '.host // "127.0.0.1"' "$CONFIG_FILE" 2>/dev/null || echo "127.0.0.1")
BASE_URL="http://${HOST}:${PORT}"

ICON_OFF=$'\uf5dc'
ICON_ON=$'\uf111'
ICON_SLEEP=$'\uf186'
ICON_PREFILL=$'\uf0ab'
ICON_GENERATING=$'\uf0e7'

output_json() {
    jq -nc --arg text "$1" --arg tooltip "$2" --arg class "$3" \
        '{text: $text, tooltip: $tooltip, class: $class}'
}

get_state() {
    local key="$1" def="$2"
    local v
    v=$(jq -r --arg k "$key" '.[$k] // empty' "$STATE_FILE" 2>/dev/null)
    [ -n "$v" ] && [ "$v" != "null" ] && echo "$v" || echo "$def"
}

save_state() {
    local st="$1" dl="$2" tps="$3"
    jq -nc \
        --argjson last_poll "$now" \
        --arg state "$st" \
        --argjson delay "$dl" \
        --arg last_tps "$tps" \
        --argjson prev_n_decoded "$prev_n_decoded" \
        --argjson prev_n_prompt_processed "$prev_n_prompt_processed" \
        --argjson prev_n_prompt_tokens "$prev_n_prompt_tokens" \
        --argjson idle_since "$idle_since" \
        --arg model_alias "$model_alias" \
        --arg short_model "$short_model" \
        --arg n_ctx "$n_ctx" \
        --argjson total_slots "$total_slots" \
        --arg is_sleeping "$is_sleeping" \
        --arg spec_types "$spec_types" \
        --argjson props_ts "$props_ts" \
        --argjson n_prompt_tokens "$n_prompt_tokens" \
        --argjson n_prompt_tokens_processed "$n_prompt_tokens_processed" \
        --argjson n_decoded "$n_decoded" \
        --argjson n_remain "$n_remain" \
        '{last_poll:$last_poll, state:$state, delay:$delay, last_tps:$last_tps, prev_n_decoded:$prev_n_decoded, prev_n_prompt_processed:$prev_n_prompt_processed, prev_n_prompt_tokens:$prev_n_prompt_tokens, idle_since:$idle_since, model_alias:$model_alias, short_model:$short_model, n_ctx:$n_ctx, total_slots:$total_slots, is_sleeping:$is_sleeping, spec_types:$spec_types, props_ts:$props_ts, n_prompt_tokens:$n_prompt_tokens, n_prompt_tokens_processed:$n_prompt_tokens_processed, n_decoded:$n_decoded, n_remain:$n_remain}' > "$STATE_FILE"
}

build_tooltip() {
    local t="Model: ${model_alias}"
    t+=$'\n'"Context: ${n_ctx} tokens"
    t+=$'\n'"Slots: ${total_slots}"
    t+=$'\n'"Sleeping: ${is_sleeping}"
    if [ "$state" = "prefill" ] || [ "$state" = "busy" ] || [ "$state" = "generating" ]; then
        if [ "$n_prompt_tokens" -gt 0 ] 2>/dev/null; then
            t+=$'\n'"Prompt: ${n_prompt_tokens_processed}/${n_prompt_tokens} processed"
        fi
        if [ "$state" = "generating" ] && [ "$n_decoded" -gt 0 ] 2>/dev/null; then
            t+=$'\n'"Decoded: ${n_decoded} tokens"
        fi
        if [ "$state" = "generating" ] && [ "$n_remain" -ge 0 ] 2>/dev/null; then
            t+=$'\n'"Remaining: ${n_remain} tokens"
        fi
    fi
    if [ -n "$spec_types" ] && [ "$spec_types" != "none" ]; then
        t+=$'\n'"Speculative: ${spec_types}"
    fi
    t+=$'\n'"URL: ${BASE_URL}"
    echo "$t"
}

render_cached() {
    local text class="remote-offline"
    case "$state" in
        idle)
            text="${ICON_ON} ${short_model}"
            class="remote-idle"
            ;;
        prefill)
            text="${ICON_PREFILL} ${short_model}"
            class="remote-prefill"
            ;;
        generating)
            text="${ICON_GENERATING} ${short_model}"
            class="remote-generating"
            ;;
        busy)
            text="${ICON_PREFILL} ${short_model} …"
            class="remote-prefill"
            ;;
        sleeping)
            text="${ICON_SLEEP} ${short_model}"
            class="remote-sleeping"
            ;;
        *)
            text="${ICON_OFF} Remote"
            class="remote-offline"
            ;;
    esac
    output_json "$text" "$(build_tooltip)" "$class"
}

now=$(date +%s.%N)

LOCK_FILE="/tmp/llama-remote-waybar.lock"
exec 9>"$LOCK_FILE"

prev_state=$(get_state state offline)
last_poll=$(get_state last_poll 0)
delay=$(get_state delay 0)
last_tps=$(get_state last_tps "")
prev_n_decoded=$(get_state prev_n_decoded 0)
prev_n_prompt_processed=$(get_state prev_n_prompt_processed 0)
prev_n_prompt_tokens=$(get_state prev_n_prompt_tokens 0)
idle_since=$(get_state idle_since "$now")
model_alias=$(get_state model_alias "unknown")
short_model=$(get_state short_model "model")
if [ "$model_alias" != "unknown" ]; then
    short_model=$(basename "$model_alias" 2>/dev/null | sed 's/\.gguf$//' | cut -c1-10)
fi
[ -z "$short_model" ] && short_model="model"
n_ctx=$(get_state n_ctx "?")
total_slots=$(get_state total_slots 1)
is_sleeping=$(get_state is_sleeping false)
spec_types=$(get_state spec_types "")
props_ts=$(get_state props_ts 0)
n_prompt_tokens=$(get_state n_prompt_tokens 0)
n_prompt_tokens_processed=$(get_state n_prompt_tokens_processed 0)
n_decoded=$(get_state n_decoded 0)
n_remain=$(get_state n_remain 0)

if ! flock -n 9 2>/dev/null; then
    state="$prev_state"
    render_cached
    exit 0
fi

due=$(awk -v n="$now" -v lp="$last_poll" -v d="$delay" 'BEGIN { if (n - lp >= d) print 1; else print 0 }')
if [ "$due" != "1" ]; then
    state="$prev_state"
    render_cached
    exit 0
fi

state="$prev_state"

if [ "$prev_state" = "offline" ]; then
    health=$(curl -s --connect-timeout 1 --max-time 2 "${BASE_URL}/health" 2>/dev/null || echo "")
else
    health=$(curl -s --max-time 1 "${BASE_URL}/health" 2>/dev/null || echo "")
fi

if [ -z "$health" ]; then
    state="offline"
    save_state offline 30 ""
    output_json "${ICON_OFF} Remote" "Remote server offline"$'\n'"${BASE_URL}" "remote-offline"
    exit 0
fi

status=$(echo "$health" | jq -r '.status // ""' 2>/dev/null || echo "")
if [ "$status" != "ok" ]; then
    state="offline"
    save_state offline 30 ""
    output_json "${ICON_OFF} Remote" "Remote server loading..."$'\n'"${BASE_URL}" "remote-offline"
    exit 0
fi

props_due=$(awk -v n="$now" -v t="$props_ts" -v s="$prev_state" 'BEGIN { if (s == "sleeping") print 1; else print (n - t >= 60) ? 1 : 0 }')
if [ "$props_due" = "1" ]; then
    props=$(curl -s --max-time 2 "${BASE_URL}/props" 2>/dev/null || echo "")
    if [ -n "$props" ]; then
        ma=$(echo "$props" | jq -r '.model_alias // empty' 2>/dev/null)
        if [ -n "$ma" ]; then
            model_alias="$ma"
            short_model=$(basename "$model_alias" 2>/dev/null | sed 's/\.gguf$//' | cut -c1-10)
            [ -z "$short_model" ] && short_model="model"
        fi
        n_ctx=$(echo "$props" | jq -r '.default_generation_settings.n_ctx // "?"' 2>/dev/null)
        total_slots=$(echo "$props" | jq -r '.total_slots // 1' 2>/dev/null)
        is_sleeping=$(echo "$props" | jq -r '.is_sleeping // false' 2>/dev/null)
        props_ts="$now"
    fi
fi

if [ "$is_sleeping" = "true" ]; then
    state="sleeping"
    save_state sleeping 15 ""
    output_json "${ICON_SLEEP} ${short_model}" "$(build_tooltip)" "remote-sleeping"
    exit 0
fi

curl_timeout=1
case "$prev_state" in
    generating|prefill|busy) curl_timeout=5 ;;
esac

slots=$(curl -s --max-time "$curl_timeout" "${BASE_URL}/slots" 2>/dev/null || echo "")
if [ -z "$slots" ]; then
    state="busy"
    save_state busy 2 "$last_tps"
    output_json "${ICON_PREFILL} ${short_model} …" "$(build_tooltip)" "remote-prefill"
    exit 0
fi

spec_types=$(echo "$slots" | jq -r '.[0].params."speculative.types" // ""' 2>/dev/null)

processing_slot=$(echo "$slots" | jq -c '[.[] | select(.is_processing == true)] | .[0] // empty' 2>/dev/null)

if [ -n "$processing_slot" ] && [ "$processing_slot" != "null" ]; then
    cur_n_prompt_tokens=$(echo "$processing_slot" | jq -r '.n_prompt_tokens // 0' 2>/dev/null || echo 0)
    cur_n_prompt_processed=$(echo "$processing_slot" | jq -r '.n_prompt_tokens_processed // 0' 2>/dev/null || echo 0)
    cur_n_decoded=$(echo "$processing_slot" | jq -r '.next_token[0].n_decoded // 0' 2>/dev/null || echo 0)
    cur_n_remain=$(echo "$processing_slot" | jq -r '.next_token[0].n_remain // 0' 2>/dev/null || echo 0)

    dt=$(awk -v n="$now" -v lp="$last_poll" 'BEGIN { d = n - lp; if (d < 0.5 || d > 20) d = 0; print d }')
    delta_ok=0
    case "$prev_state" in
        prefill|generating|busy) delta_ok=1 ;;
    esac
    tps=""

    rem=$(awk -v t="$cur_n_prompt_tokens" -v nd="$cur_n_decoded" 'BEGIN { r = t - nd; if (r < 0) r = 0; print int(r) }')
    if [ "$cur_n_prompt_processed" -lt "$rem" ] 2>/dev/null; then
        if [ "$delta_ok" = "1" ]; then
            d_pp=$(awk -v c="$cur_n_prompt_processed" -v p="$prev_n_prompt_processed" -v t="$cur_n_prompt_tokens" -v nd="$cur_n_decoded" -v pt="$prev_n_prompt_tokens" -v pnd="$prev_n_decoded" 'BEGIN { if ((t - nd) == (pt - pnd)) { d = c - p; if (d < 0) d = 0; print d } else print 0 }')
            if [ "$d_pp" -gt 0 ] 2>/dev/null && [ "$dt" != "0" ]; then
                tps=$(awk -v d="$d_pp" -v dt="$dt" 'BEGIN { printf "%.1f", d / dt }')
            fi
        fi
        [ -z "$tps" ] && tps="$last_tps"
        state="prefill"
        n_prompt_tokens="$cur_n_prompt_tokens"
        n_prompt_tokens_processed="$cur_n_prompt_processed"
        n_decoded="$cur_n_decoded"
        n_remain="$cur_n_remain"
        prev_n_prompt_tokens="$cur_n_prompt_tokens"
        prev_n_prompt_processed="$cur_n_prompt_processed"
        prev_n_decoded="$cur_n_decoded"
        text="${ICON_PREFILL} ${short_model}"
        save_state "$state" 1 "$tps"
        output_json "$text" "$(build_tooltip)" "remote-prefill"
        exit 0
    fi

    d_dec=0
    if [ "$delta_ok" = "1" ]; then
        d_dec=$(awk -v c="$cur_n_decoded" -v p="$prev_n_decoded" 'BEGIN { d = c - p; if (d < 0) d = 0; print d }')
    fi
    if [ "$d_dec" -gt 0 ] 2>/dev/null && [ "$dt" != "0" ]; then
        tps=$(awk -v d="$d_dec" -v dt="$dt" 'BEGIN { printf "%.1f", d / dt }')
    fi
    [ -z "$tps" ] && tps="$last_tps"
    state="generating"
    n_prompt_tokens="$cur_n_prompt_tokens"
    n_prompt_tokens_processed="$cur_n_prompt_processed"
    n_decoded="$cur_n_decoded"
    n_remain="$cur_n_remain"
    prev_n_prompt_tokens="$cur_n_prompt_tokens"
    prev_n_prompt_processed="$cur_n_prompt_processed"
    prev_n_decoded="$cur_n_decoded"
        text="${ICON_GENERATING} ${short_model}"
        save_state "$state" 1 "$tps"
    output_json "$text" "$(build_tooltip)" "remote-generating"
    exit 0
fi

if [ "$prev_state" != "idle" ]; then
    idle_since="$now"
fi
dur=$(awk -v n="$now" -v s="$idle_since" 'BEGIN { d = n - s; if (d < 0) d = 0; print int(d) }')
if [ "$dur" -lt 120 ]; then
    delay=5
elif [ "$dur" -lt 300 ]; then
    delay=10
else
    delay=20
fi
state="idle"
save_state idle "$delay" ""
output_json "${ICON_ON} ${short_model}" "$(build_tooltip)" "remote-idle"
