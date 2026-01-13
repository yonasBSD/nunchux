#!/usr/bin/env bash
# Nunchux TPM plugin
# Adds a keybinding to launch nunchux in a popup

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NUNCHUX_BIN="$CURRENT_DIR/bin/nunchux"

# Default keybinding (can be overridden with @nunchux-key)
default_key="C-Space"

# Detect platform (os-arch)
get_platform() {
    local os arch
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)

    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
    esac

    echo "${os}-${arch}"
}

# Download binary from GitHub releases
download_binary() {
    local platform="$1"
    local url="https://github.com/datamadsen/nunchux/releases/latest/download/nunchux-${platform}"

    mkdir -p "$CURRENT_DIR/bin"
    if command -v curl &>/dev/null; then
        curl -fsSL "$url" -o "$NUNCHUX_BIN"
    elif command -v wget &>/dev/null; then
        wget -qO "$NUNCHUX_BIN" "$url"
    else
        tmux display-message "nunchux: curl or wget required to download binary"
        return 1
    fi
    chmod +x "$NUNCHUX_BIN"
    echo "$platform" > "$CURRENT_DIR/bin/.platform"
}

# Ensure binary exists and matches platform
ensure_binary() {
    local platform
    platform=$(get_platform)

    # Check if binary exists and matches current platform
    if [[ ! -x "$NUNCHUX_BIN" ]]; then
        tmux display-message "nunchux: downloading binary for ${platform}..."
        download_binary "$platform" || return 1
    elif [[ -f "$CURRENT_DIR/bin/.platform" ]]; then
        local cached_platform
        cached_platform=$(cat "$CURRENT_DIR/bin/.platform")
        if [[ "$cached_platform" != "$platform" ]]; then
            tmux display-message "nunchux: platform changed, re-downloading..."
            download_binary "$platform" || return 1
        fi
    fi
}

# Get tmux option or return default
get_tmux_option() {
    local option="$1"
    local default_value="$2"
    local value
    value=$(tmux show-option -gqv "$option")
    if [[ -z "$value" ]]; then
        echo "$default_value"
    else
        echo "$value"
    fi
}

# Read nunchux config to get dimensions
get_config_value() {
    local key="$1"
    local default="$2"
    local config_file

    # Check for config in standard locations
    if [[ -n "$NUNCHUX_RC_FILE" && -f "$NUNCHUX_RC_FILE" ]]; then
        config_file="$NUNCHUX_RC_FILE"
    elif [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/nunchux/config" ]]; then
        config_file="${XDG_CONFIG_HOME:-$HOME/.config}/nunchux/config"
    else
        echo "$default"
        return
    fi

    local value
    value=$(grep -E "^${key}\s*=" "$config_file" 2>/dev/null | head -1 | sed 's/.*=\s*//' | tr -d ' ')
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

main() {
    # Download binary if needed
    ensure_binary

    local key
    key=$(get_tmux_option "@nunchux-key" "$default_key")

    # Get dimensions from config
    local width height label
    width=$(get_config_value "menu_width" "60%")
    height=$(get_config_value "menu_height" "50%")
    label=$(get_config_value "label" "nunchux")

    # Environment inheritance: tell nunchux-run where to find the saved env
    # (saved by shell hook from --shell-init)
    local env_file='/tmp/nunchux-env-#{pane_id}'
    local setup_cmd="tmux set-environment NUNCHUX_ENV_FILE '$env_file'"

    # Build the popup command (no tmux border, fzf provides its own)
    # -d sets working directory to current pane's path so local .nunchuxrc is found
    # Dimension clamping happens at runtime for absolute values
    local popup_cmd
    if [[ "$width" =~ % && "$height" =~ % ]]; then
        # Both are percentages, use directly
        popup_cmd="tmux display-popup -E -B -d '#{pane_current_path}' -w '$width' -h '$height' '$NUNCHUX_BIN'"
    else
        # At least one is absolute - clamp at runtime
        popup_cmd="bash -c 'w=$width; h=$height; tw=#{window_width}; th=#{window_height}; [[ ! \$w =~ % && \$w -ge \$tw ]] && w=\$tw; [[ ! \$h =~ % && \$h -ge \$th ]] && h=\$th; tmux display-popup -E -B -d \"#{pane_current_path}\" -w \"\$w\" -h \"\$h\" \"$NUNCHUX_BIN\"'"
    fi

    # Set up the keybinding
    # Keys with "-" (like C-Space, C-g) bind without prefix, others require prefix
    local bind_opts=""
    [[ $key == *"-"* ]] && bind_opts="-n"
    tmux bind-key $bind_opts "$key" run-shell "$setup_cmd; $popup_cmd"
}

main
