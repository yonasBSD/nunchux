#!/usr/bin/env bash
#
# lib/onboarding.sh - First-run onboarding and setup wizard for nunchux
#
# This module handles:
# - No config file scenario (show_no_config_popup)
# - Interactive setup wizard (show_setup_wizard)
# - Empty config fallback menu (build_empty_config_menu)
#
# This module is lazy-loaded only when needed for performance.

# Guard against double-sourcing
[[ -n "${NUNCHUX_LIB_ONBOARDING_LOADED:-}" ]] && return
NUNCHUX_LIB_ONBOARDING_LOADED=1

# Load config_templates.sh (lazy-loaded together with onboarding)
source "$NUNCHUX_LIB_DIR/config_templates.sh"

# ============================================================================
# Shared box drawing helpers
# ============================================================================

_ONBOARD_BORDER_COLOR="\033[90m"
_ONBOARD_RESET="\033[0m"

# Draw a line of content inside a box
# Usage: _onboard_box_line WIDTH CONTENT
_onboard_box_line() {
  local box_width="$1"
  local content="$2"
  local term_width
  term_width=$(tput cols 2>/dev/null || echo 80)
  local padding=$(((term_width - box_width) / 2))
  [[ $padding -gt 0 ]] && printf "%*s" $padding ""
  local plain
  plain=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
  local content_len=${#plain}
  local inner_width=$((box_width - 4))
  local right_pad=$((inner_width - content_len))
  [[ $right_pad -lt 0 ]] && right_pad=0
  printf "${_ONBOARD_BORDER_COLOR}│${_ONBOARD_RESET} "
  printf "%b" "$content"
  printf "%*s" $right_pad ""
  printf " ${_ONBOARD_BORDER_COLOR}│${_ONBOARD_RESET}\n"
}

# Draw top border of a box
# Usage: _onboard_box_top WIDTH
_onboard_box_top() {
  local box_width="$1"
  local term_width
  term_width=$(tput cols 2>/dev/null || echo 80)
  local padding=$(((term_width - box_width) / 2))
  [[ $padding -gt 0 ]] && printf "%*s" $padding ""
  printf "${_ONBOARD_BORDER_COLOR}╭"
  printf '─%.0s' $(seq 1 $((box_width - 2)))
  printf "╮${_ONBOARD_RESET}\n"
}

# Draw bottom border of a box
# Usage: _onboard_box_bottom WIDTH
_onboard_box_bottom() {
  local box_width="$1"
  local term_width
  term_width=$(tput cols 2>/dev/null || echo 80)
  local padding=$(((term_width - box_width) / 2))
  [[ $padding -gt 0 ]] && printf "%*s" $padding ""
  printf "${_ONBOARD_BORDER_COLOR}╰"
  printf '─%.0s' $(seq 1 $((box_width - 2)))
  printf "╯${_ONBOARD_RESET}\n"
}

# Center content vertically on screen
# Usage: _onboard_center_vertical HEIGHT
_onboard_center_vertical() {
  local content_height="$1"
  local term_height
  term_height=$(tput lines 2>/dev/null || echo 24)
  local top_padding=$(((term_height - content_height) / 2))
  for ((i = 0; i < top_padding; i++)); do echo; done
}

# ============================================================================
# No config popup
# ============================================================================

# Show popup when no config file exists
# Offers: setup wizard, quick setup, or exit (radio button selection)
show_no_config_popup() {
  local config_file="$NUNCHUX_RC_FILE"
  local box_width=50
  local cursor=0
  local -a options=("Setup wizard (detects installed tools)" "Quick setup (minimal config)")

  _draw_noconfig_screen() {
    clear
    _onboard_center_vertical 12
    _onboard_box_top $box_width
    _onboard_box_line $box_width ""
    _onboard_box_line $box_width "\033[1;36mNo config file found\033[0m"
    _onboard_box_line $box_width ""
    _onboard_box_line $box_width "Create one to get started?"
    _onboard_box_line $box_width ""

    for i in "${!options[@]}"; do
      local pointer="  "
      local radio="\033[90m( )\033[0m"
      local label_color="\033[0m"
      if [[ $cursor -eq $i ]]; then
        pointer="\033[36m>\033[0m "
        radio="\033[36m(o)\033[0m"
        label_color="\033[1m"
      fi
      _onboard_box_line $box_width "${pointer}${radio} ${label_color}${options[$i]}\033[0m"
    done

    _onboard_box_line $box_width ""
    _onboard_box_line $box_width "\033[90m[Enter] Select  [Esc] Exit\033[0m"
    _onboard_box_line $box_width ""
    _onboard_box_bottom $box_width
  }

  # Hide cursor
  tput civis 2>/dev/null || true

  _draw_noconfig_screen

  while true; do
    read -rsn1 key

    case "$key" in
      $'\x1b')
        read -rsn2 -t 0.01 seq
        if [[ -z "$seq" ]]; then
          # Plain Escape - exit
          tput cnorm 2>/dev/null || true
          exit 0
        fi
        case "$seq" in
          '[A') ((cursor > 0)) && ((cursor--)) || true ;;
          '[B') ((cursor < 1)) && ((cursor++)) || true ;;
        esac
        ;;
      k) ((cursor > 0)) && ((cursor--)) || true ;;
      j) ((cursor < 1)) && ((cursor++)) || true ;;
      "")
        # Enter - execute selected option
        tput cnorm 2>/dev/null || true
        if [[ $cursor -eq 0 ]]; then
          # Setup wizard
          local script_path="$NUNCHUX_BIN_DIR/nunchux"
          tmux run-shell -b "sleep 0.05; tmux display-popup -E -w 70 -h 24 '$script_path --setup-wizard' || true"
          exit 0
        else
          # Quick setup
          generate_minimal_config "$config_file"
          _show_success_screen "$config_file"
          exit 0
        fi
        ;;
    esac

    _draw_noconfig_screen
  done
}

# ============================================================================
# Setup wizard
# ============================================================================

# Main setup wizard - interactive tool selection
# Usage: show_setup_wizard
# Runs interactively and creates config file
show_setup_wizard() {
  local config_file="${NUNCHUX_RC_FILE:-$HOME/.config/nunchux/config}"
  local box_width=60

  # Detect installed tools
  local -a detected_tools=()
  local -a tool_names=()
  local -a tool_descs=()
  local -a selected=()
  local cursor=0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    detected_tools+=("$line")
    local rest="${line#*:}"
    local name="${rest%%:*}"
    rest="${rest#*:}"
    local desc="${rest%%:*}"
    tool_names+=("$name")
    tool_descs+=("$desc")
    selected+=(1)  # Pre-select all detected tools
  done < <(detect_installed_tools)

  # If no tools detected, just create minimal config
  if [[ ${#detected_tools[@]} -eq 0 ]]; then
    generate_minimal_config "$config_file"
    _show_success_screen "$config_file"
    return 0
  fi

  _draw_wizard_tools() {
    clear
    _onboard_center_vertical $((16 + ${#detected_tools[@]}))

    _onboard_box_top $box_width
    _onboard_box_line $box_width ""
    _onboard_box_line $box_width "\033[1;36m       Setup Wizard\033[0m"
    _onboard_box_line $box_width ""
    _onboard_box_line $box_width "\033[90mFound ${#detected_tools[@]} tools on your system.\033[0m"
    _onboard_box_line $box_width "\033[90mSelect which ones to add to nunchux:\033[0m"
    _onboard_box_line $box_width ""

    for i in "${!detected_tools[@]}"; do
      local check=" "
      [[ ${selected[$i]} -eq 1 ]] && check="✓"
      local pointer="  "
      local name_color="\033[0m"
      if [[ $cursor -eq $i ]]; then
        pointer="\033[36m▶\033[0m "
        name_color="\033[1m"
      fi
      local checkbox="\033[90m[\033[0m${check}\033[90m]\033[0m"
      _onboard_box_line $box_width "${pointer}${checkbox} ${name_color}${tool_names[$i]}\033[0m \033[90m- ${tool_descs[$i]}\033[0m"
    done

    _onboard_box_line $box_width ""
    _onboard_box_line $box_width "\033[90m[↑/↓] Navigate  [Space] Toggle  [A] All\033[0m"
    _onboard_box_line $box_width "\033[1;32m[Enter]\033[0m Create config  \033[1;31m[Esc]\033[0m Cancel"
    _onboard_box_line $box_width ""
    _onboard_box_bottom $box_width
  }

  # Hide cursor
  tput civis 2>/dev/null || true

  _draw_wizard_tools

  while true; do
    IFS= read -rsn1 key

    if [[ -z "$key" ]]; then
      # Enter - create config with selected tools
      tput cnorm 2>/dev/null || true

      # Collect selected tools
      local -a final_selection=()
      for i in "${!detected_tools[@]}"; do
        [[ ${selected[$i]} -eq 1 ]] && final_selection+=("${detected_tools[$i]}")
      done

      if [[ ${#final_selection[@]} -eq 0 ]]; then
        generate_minimal_config "$config_file"
      else
        generate_detected_config "$config_file" final_selection
      fi

      _show_success_screen "$config_file"
      return 0
    fi

    case "$key" in
      $'\x1b')
        read -rsn2 -t 0.01 seq
        if [[ -z "$seq" ]]; then
          # Plain Escape - cancel
          tput cnorm 2>/dev/null || true
          return 1
        fi
        case "$seq" in
          '[A') ((cursor > 0)) && ((cursor--)) || true ;;
          '[B') ((cursor < ${#detected_tools[@]} - 1)) && ((cursor++)) || true ;;
        esac
        ;;
      ' ')
        # Toggle with space
        if [[ ${selected[$cursor]} -eq 0 ]]; then
          selected[$cursor]=1
        else
          selected[$cursor]=0
        fi
        ;;
      a|A)
        # Toggle all
        local all_selected=1
        for s in "${selected[@]}"; do
          [[ $s -eq 0 ]] && all_selected=0 && break
        done
        local new_val=$((1 - all_selected))
        for i in "${!selected[@]}"; do
          selected[$i]=$new_val
        done
        ;;
      k) ((cursor > 0)) && ((cursor--)) || true ;;
      j) ((cursor < ${#detected_tools[@]} - 1)) && ((cursor++)) || true ;;
    esac

    _draw_wizard_tools
  done
}

# ============================================================================
# Shared success screen
# ============================================================================

# Show success screen after config creation
_show_success_screen() {
  local config_file="$1"
  local box_width=50

  clear
  _onboard_center_vertical 10

  _onboard_box_top $box_width
  _onboard_box_line $box_width ""
  _onboard_box_line $box_width "\033[1;32mConfig Created!\033[0m"
  _onboard_box_line $box_width "\033[90m$config_file\033[0m"
  _onboard_box_line $box_width ""
  _onboard_box_line $box_width "Edit it to add your apps, then run nunchux."
  _onboard_box_line $box_width "\033[90mPress any key to exit...\033[0m"
  _onboard_box_line $box_width ""
  _onboard_box_bottom $box_width

  read -rsn1
}

# ============================================================================
# Empty config fallback menu
# ============================================================================

# Build fallback menu for empty config
# Returns menu items for "Edit config" and "Open docs"
build_empty_config_menu() {
  local config_file="${NUNCHUX_RC_FILE:-$HOME/.config/nunchux/config}"
  local editor="${EDITOR:-${VISUAL:-nano}}"

  # Format: display \t shortcut \t name \t cmd \t width \t height \t on_exit
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "Edit config file" "" "__edit_config" "$editor $config_file" "" "" ""

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "Open documentation in browser" "" "__open_docs" "__browser__" "" "" ""
}

# Handle special onboarding menu items
# Returns 0 if handled, 1 if not an onboarding item
handle_onboarding_item() {
  local name="$1"
  local cmd="$2"

  case "$name" in
    __edit_config)
      # Open config in editor using tmux popup
      local popup_w="${POPUP_WIDTH:-90%}"
      local popup_h="${POPUP_HEIGHT:-90%}"
      tmux run-shell -b "sleep 0.05; tmux display-popup -E -w '$popup_w' -h '$popup_h' '$cmd'"
      return 0
      ;;
    __open_docs)
      # Open docs in browser (outside tmux)
      local docs_url="https://github.com/datamadsen/nunchux/blob/main/docs/configuration.md"
      if [[ "$(uname)" == "Darwin" ]]; then
        open "$docs_url"
      else
        xdg-open "$docs_url" 2>/dev/null || sensible-browser "$docs_url" 2>/dev/null || echo "Could not open browser"
      fi
      return 0
      ;;
  esac
  return 1
}

# vim: ft=bash ts=2 sw=2 et
