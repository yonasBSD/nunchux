#!/usr/bin/env bash
#
# nunchux.tmux - TPM plugin for nunchux launcher
#
# Add to ~/.tmux.conf:
#   set -g @plugin 'path/to/nunchux'
#
# Options:
#   set -g @nunchux-key "g"    # Keybinding (default: g)
#
# Menu dimensions are configured in ~/.config/nunchux/config

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NUNCHUX_CMD="$CURRENT_DIR/bin/nunchux"

get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local value
    value=$(tmux show-option -gqv "$option")
    echo "${value:-$default_value}"
}

main() {
    local key width height
    key=$(get_tmux_option "@nunchux-key" "g")
    width=$("$NUNCHUX_CMD" --config menu_width)
    height=$("$NUNCHUX_CMD" --config menu_height)

    # Bind key to open nunchux in a popup
    # Keys with "-" (like C-Space) bind without prefix, others require prefix
    if [[ $key == *"-"* ]]; then
        tmux bind-key -n "$key" display-popup -E -B -w "$width" -h "$height" "$NUNCHUX_CMD"
    else
        tmux bind-key "$key" display-popup -E -B -w "$width" -h "$height" "$NUNCHUX_CMD"
    fi
}

main
