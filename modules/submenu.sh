#!/usr/bin/env bash
#
# modules/submenu.sh - Submenu handling
#
# Config format:
#   [menu:system]
#   desc = System tools
#   status = echo "load: $(cut -d' ' -f1 /proc/loadavg)"
#   cache_ttl = 120
#

# Guard against double-sourcing
[[ -n "${NUNCHUX_MOD_SUBMENU_LOADED:-}" ]] && return
NUNCHUX_MOD_SUBMENU_LOADED=1

# Submenu storage (declare -g for global scope when sourced from function)
declare -gA MENU_DESC=()
declare -gA MENU_STATUS=()
declare -gA SUBMENU_CACHE_TTL=()
declare -gA MENU_SHORTCUT=()  # Per-menu keyboard shortcut
declare -ga MENU_ORDER=()

# Current submenu (empty = main menu)
CURRENT_MENU=""

# Register with core
register_module "menu"

# Parse a config section for a menu
# Called by config parser when [menu:name] is encountered
menu_parse_section() {
  local name="$1"
  local data_decl="$2"

  # Temporarily disable set -u for associative array access
  set +u

  # Reconstruct associative array from declaration
  eval "$data_decl"

  # Store menu configuration
  MENU_DESC["$name"]="${section_data[desc]:-}"
  SUBMENU_CACHE_TTL["$name"]="${section_data[cache_ttl]:-}"
  MENU_SHORTCUT["$name"]="${section_data[shortcut]:-}"

  # Handle status or status_script
  if [[ -n "${section_data[status_script]:-}" ]]; then
    local script="${section_data[status_script]}"
    MENU_STATUS["$name"]="source ${script/#\~/$HOME}"
  elif [[ -n "${section_data[status]:-}" ]]; then
    MENU_STATUS["$name"]="${section_data[status]}"
  fi

  # Parse order property
  local _order="${section_data[order]:-}"

  set -u

  MENU_ORDER+=("$name")

  # Track in global order with optional explicit order
  track_config_item "menu:$name" "$_order"
}

# Build menu entries for submenus
# Only shown in main menu (when current_menu is empty)
menu_build_menu() {
  local current_menu="${1:-}"

  # Submenus only appear in main menu
  [[ -n "$current_menu" ]] && return

  for name in "${MENU_ORDER[@]}"; do
    local desc="" status_output=""

    desc="${MENU_DESC[$name]:-}"

    # Run status command if defined
    if [[ -n "${MENU_STATUS[$name]:-}" ]]; then
      status_output=$(eval "${MENU_STATUS[$name]}" 2>/dev/null || true)
      if [[ -n "$status_output" ]]; then
        if [[ -n "$desc" ]]; then
          desc="$desc $status_output"
        else
          desc="$status_output"
        fi
      fi
    fi

    local shortcut="${MENU_SHORTCUT[$name]:-}"

    # Format: visible_part \t shortcut \t name \t (empty fields for cmd, width, height, on_exit)
    # Use menu: prefix to identify submenus
    printf "▸ %-12s  %s\t%s\t%s\t\t\t\t\n" "$name" "$desc" "$shortcut" "menu:$name"
  done
}

# Launch (enter) a submenu
# Returns 0 if handled, 1 if not our item
menu_launch() {
  local name="$1"
  local key="$2"

  # Check if this is a menu reference
  [[ "$name" != menu:* ]] && return 1

  local menu_name="${name#menu:}"

  # Easter egg: ctrl-o on submenu
  if [[ "$key" == "ctrl-o" ]]; then
    show_chuck_easter_egg
    return 0
  fi

  # Enter the submenu
  CURRENT_MENU="$menu_name"
  FZF_BORDER_LABEL=" $NUNCHUX_LABEL: $menu_name "

  return 0
}

# Get cache TTL for a menu
menu_get_cache_ttl() {
  local name="$1"
  echo "${SUBMENU_CACHE_TTL[$name]:-$MENU_CACHE_TTL}"
}

# Check if we have any menus configured
menu_has_items() {
  [[ ${#MENU_ORDER[@]} -gt 0 ]]
}

# Easter egg: Chuck Norris fact when trying to open submenu in window
show_chuck_easter_egg() {
  local fact="${CHUCK_FACTS[$RANDOM % ${#CHUCK_FACTS[@]}]}"
  local script_file="/tmp/nunchux-popup-$$"

  cat >"$script_file" <<NUNCHUX_EOF
#!/usr/bin/env bash

center() {
    local text="\$1"
    local width=\$(tput cols)
    local plain=\$(echo -e "\$text" | sed 's/\x1b\[[0-9;]*m//g')
    local text_len=\${#plain}
    local padding=\$(( (width - text_len) / 2 ))
    [[ \$padding -gt 0 ]] && printf "%*s" \$padding ""
    echo -e "\$text"
}

clear

height=\$(tput lines)
top_padding=\$(( (height - 18) / 2 ))
for ((i=0; i<top_padding; i++)); do echo; done

center "\033[1;33m$fact\033[0m"
echo ""
center "\033[90mbut...\033[0m"
echo ""
while IFS= read -r line; do
    center "\$line"
done <<< "$NUNCHUCKS_ART"
echo ""
echo ""
center "\033[1;31mYou can't open a submenu in a window\033[0m"
echo ""
center "\033[90mpress any key\033[0m"
read -n 1 -s
rm -f "\$0"
NUNCHUX_EOF

  chmod +x "$script_file"
  tmux run-shell -b "sleep 0.05; tmux display-popup -E -b rounded -w $MENU_WIDTH -h $MENU_HEIGHT '$script_file'"
  exit 0
}

# vim: ft=bash ts=2 sw=2 et
