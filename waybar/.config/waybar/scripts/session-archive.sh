#!/usr/bin/env bash
#
# Session archive wrapper for waybar.
# Usage:
#   session-archive.sh module   → JSON output for waybar
#   session-archive.sh          → Run full export (on click)

SCRIPT_DIR="$(dirname "$0")"
PY_SCRIPT="$SCRIPT_DIR/session-archive.py"

main() {
    local arg="${1:-}"

    case "$arg" in
        module)
            python3 "$PY_SCRIPT" --module
            ;;
        *)
            # Run full export in background, notify on completion
            python3 "$PY_SCRIPT"
            ;;
    esac
}

main "$@"
