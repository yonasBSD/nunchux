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
    local key width height max_width max_height
    key=$(get_tmux_option "@nunchux-key" "g")
    width=$("$NUNCHUX_CMD" --config menu_width)
    height=$("$NUNCHUX_CMD" --config menu_height)
    max_width=$("$NUNCHUX_CMD" --config max_menu_width)
    max_height=$("$NUNCHUX_CMD" --config max_menu_height)

    # Bind key to open nunchux in a popup
    # Keys with "-" (like C-Space) bind without prefix, others require prefix
    #
    # Environment inheritance:
    # The env file is created by a shell hook (added to .bashrc/.zshrc).
    # This captures the current shell environment after each command,
    # so nunchux can inherit it even when launched from within vim/etc.
    #
    # To enable, add to your shell rc:
    #   source ~/.tmux/plugins/nunchux/shell-init.bash
    local env_file='/tmp/nunchux-env-#{pane_id}'
    local setup_cmd="tmux set-environment NUNCHUX_PARENT_PANE '#{pane_id}'; tmux set-environment NUNCHUX_ENV_FILE '$env_file'"

    # Launch nunchux with --popup flag, which handles dimension clamping internally
    local popup_cmd="$NUNCHUX_CMD --popup"

    local bind_opts=""
    [[ $key == *"-"* ]] && bind_opts="-n"
    tmux bind-key $bind_opts "$key" run-shell "$setup_cmd; $popup_cmd"
}

main

# vim: ft=tmux ts=2 sw=2 et
