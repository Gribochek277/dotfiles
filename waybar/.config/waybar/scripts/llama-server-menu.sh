#!/usr/bin/env bash

CONFIG_FILE="${LLAMA_SERVER_CONFIG:-$HOME/.config/waybar/scripts/llama-server-config.json}"
THEME_FILE="$HOME/.config/waybar/theme.css"
MENU_CSS="/tmp/llama-menu-generated.css"

LLAMACPP_DIR=$(jq -r '.llamacpp_dir // "$HOME/llamacpp"' "$CONFIG_FILE")
PORT=$(jq -r '.port // 8080' "$CONFIG_FILE")
HOST=$(jq -r '.host // "127.0.0.1"' "$CONFIG_FILE")
LOG_FILE=$(jq -r '.log_file // "/tmp/llama-server.log"' "$CONFIG_FILE")
PID_FILE=$(jq -r '.pid_file // "/tmp/llama-server.pid"' "$CONFIG_FILE")
SCRIPT_FILE=$(jq -r '.script_file // "/tmp/llama-server-script"' "$CONFIG_FILE")
BASE_URL="http://${HOST}:${PORT}"

generate_menu_css() {
    local fg="#699bbd" bg="#142022"
    if [ -f "$THEME_FILE" ]; then
        fg=$(grep '@define-color foreground' "$THEME_FILE" | grep -oE '#[0-9a-fA-F]{6}' | head -1)
        bg=$(grep '@define-color background' "$THEME_FILE" | grep -oE '#[0-9a-fA-F]{6}' | head -1)
    fi
    fg="${fg:-#699bbd}"
    bg="${bg:-#142022}"

    local fr=$(( 0x${fg:1:2} )) fg_=$(( 0x${fg:3:2} )) fb=$(( 0x${fg:5:2} ))
    local br=$(( 0x${bg:1:2} )) bg_=$(( 0x${bg:3:2} )) bb=$(( 0x${bg:5:2} ))

    local mr=$(( (fr * 20 + br * 80) / 100 ))
    local mg=$(( (fg_ * 20 + bg_ * 80) / 100 ))
    local mb=$(( (fb * 20 + bb * 80) / 100 ))
    local sel_bg=$(printf '#%02x%02x%02x' "$mr" "$mg" "$mb")

    local dr=$(( (fr * 30 + br * 70) / 100 ))
    local dg=$(( (fg_ * 30 + bg_ * 70) / 100 ))
    local db=$(( (fb * 30 + bb * 70) / 100 ))
    local border=$(printf '#%02x%02x%02x' "$dr" "$dg" "$db")

    cat > "$MENU_CSS" << EOF
window {
    background-color: ${bg};
    border: 1px solid ${border};
    border-radius: 4px;
    font-family: 'JetBrainsMonoNerdFontMono';
    font-size: 12px;
    color: ${fg};
}
#input {
    padding: 6px 12px;
    border: none;
    border-bottom: 1px solid ${border};
    background: transparent;
    color: ${fg};
}
#entry {
    padding: 6px 16px;
    margin: 0 4px;
}
#entry:selected {
    background-color: ${sel_bg};
    border-radius: 2px;
}
EOF
}

IC_START=$'\uf04b'
IC_STOP=$'\uf04d'
IC_RESTART=$'\uf021'
IC_LOGS=$'\uf022'
IC_CONFIG=$'\uf013'
IC_WEB=$'\uf0ac'
IC_RUNNING=$'\uf111'
IC_OFFLINE=$'\uf011'

notify() {
    notify-send "llama-server" "$1" 2>/dev/null
}

is_running() {
    curl -s --max-time 1 "${BASE_URL}/health" 2>/dev/null | grep -q '"ok"'
}

get_last_script() {
    [ -f "$SCRIPT_FILE" ] && cat "$SCRIPT_FILE" 2>/dev/null
}

start_script() {
    local script="$1"
    PATH="$LLAMACPP_DIR:$PATH" nohup "$script" > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "$script" > "$SCRIPT_FILE"
    notify "Started $(basename "$script" .sh): PID $!"
}

stop_server() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE")
        rm -f "$PID_FILE"
        [ -n "$pid" ] && kill -SIGTERM "$pid" 2>/dev/null
    fi
    pkill -SIGTERM -x "llama-server" 2>/dev/null
    sleep 1
    if pgrep -x "llama-server" >/dev/null 2>&1; then
        pkill -SIGKILL -x "llama-server" 2>/dev/null
    fi
    notify "Stopped"
}

switch_model() {
    local script="$1"
    if is_running; then
        stop_server
        sleep 1
    fi
    start_script "$script"
}

scan_scripts() {
    local scripts=()
    for f in "$LLAMACPP_DIR"/run-*.sh; do
        [ -f "$f" ] || continue
        local name
        name=$(basename "$f" .sh)
        name="${name#run-}"
        scripts+=("${IC_START} ${name}|${f}")
    done
    printf '%s\n' "${scripts[@]}"
}

main() {
    generate_menu_css
    local items=()
    declare -A script_map

    while IFS='|' read -r label path; do
        items+=("$label")
        script_map["$label"]="$path"
    done < <(scan_scripts)

    if is_running; then
        items+=("${IC_STOP} Stop")
        items+=("${IC_RESTART} Restart")
    fi

    items+=("${IC_LOGS} View Logs")
    items+=("${IC_WEB} Open Web UI")
    items+=("${IC_CONFIG} Edit Config")

    local height
    height=$(( ${#items[@]} * 30 + 40 ))
    [ "$height" -gt 400 ] && height=400

    local menu_input
    menu_input=$(printf '%s\n' "${items[@]}")

    local selected
    selected=$(echo "$menu_input" | wofi --dmenu --prompt "" -W 240 -H "$height" -s "$MENU_CSS" -i 2>/dev/null)

    [ -z "$selected" ] && exit 0

    case "$selected" in
    "${IC_STOP}"*)
        stop_server
        ;;
    "${IC_RESTART}"*)
        local last
        last=$(get_last_script)
        if [ -n "$last" ] && [ -f "$last" ]; then
            stop_server
            sleep 1
            start_script "$last"
        else
            notify "No script to restart"
        fi
        ;;
    "${IC_LOGS}"*)
        kitty -e tail -f "$LOG_FILE" &
        ;;
    "${IC_WEB}"*)
        xdg-open "${BASE_URL}" 2>/dev/null &
        ;;
    "${IC_CONFIG}"*)
        kitty -e "${EDITOR:-nvim}" "$CONFIG_FILE" &
        ;;
    "${IC_START}"*)
        local script="${script_map[$selected]}"
        if [ -n "$script" ] && [ -f "$script" ]; then
            switch_model "$script"
        fi
        ;;
    esac
}

main
