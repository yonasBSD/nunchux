#!/usr/bin/env bash
#
# lib/core.sh - Core initialization and shared state for nunchux
#

# Guard against double-sourcing
[[ -n "${NUNCHUX_LIB_CORE_LOADED:-}" ]] && return
NUNCHUX_LIB_CORE_LOADED=1

# Determine library directory (handle both relative and absolute paths)
NUNCHUX_LIB_DIR="$(cd "${BASH_SOURCE%/*}" 2>/dev/null && pwd)"
NUNCHUX_ROOT_DIR="${NUNCHUX_LIB_DIR%/*}"
NUNCHUX_BIN_DIR="$NUNCHUX_ROOT_DIR/bin"
NUNCHUX_MODULES_DIR="$NUNCHUX_ROOT_DIR/modules"
NUNCHUX_TASKRUNNERS_DIR="$NUNCHUX_ROOT_DIR/taskrunners"

# Add bin to PATH if not already there
if [[ ":$PATH:" != *":$NUNCHUX_BIN_DIR:"* ]]; then
  export PATH="$NUNCHUX_BIN_DIR:$PATH"
fi

# Load all library modules
source "$NUNCHUX_LIB_DIR/utils.sh"
source "$NUNCHUX_LIB_DIR/cache.sh"
source "$NUNCHUX_LIB_DIR/menu.sh"
source "$NUNCHUX_LIB_DIR/config.sh"
source "$NUNCHUX_LIB_DIR/migrate.sh"

# Module registry (declare -g for global scope)
declare -ga LOADED_MODULES=()
declare -gA MODULE_HANDLERS=()

# Register a module
# Modules must implement: module_type, module_parse_section, module_build_menu, module_launch
register_module() {
  local type="$1"
  LOADED_MODULES+=("$type")
  register_config_type "$type" "${type}_parse_section"
}

# Load all modules from modules directory
load_modules() {
  if [[ -d "$NUNCHUX_MODULES_DIR" ]]; then
    for mod_file in "$NUNCHUX_MODULES_DIR"/*.sh; do
      [[ -f "$mod_file" ]] || continue
      source "$mod_file"
    done
  fi
}

# Build combined menu from all modules (sorted by config order)
build_combined_menu() {
  local current_menu="${1:-}"
  local -a menu_lines=()
  local -a order_keys=()

  # Collect output from all modules
  for mod in "${LOADED_MODULES[@]}"; do
    local builder="${mod}_build_menu"
    if [[ $(type -t "$builder") == "function" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        menu_lines+=("$line")

        # Extract item name from line (second tab-separated field)
        local item_name
        item_name=$(echo "$line" | cut -f2)

        # Check if this is a divider line (taskrunner section header)
        if [[ "$line" == *"───"* ]]; then
          # Parse runner name from divider: "   ─── label icon ───..."
          # The label is after "─── " and before the next space or emoji
          local divider_label
          divider_label=$(echo "$line" | sed 's/.*─── \([^ ]*\).*/\1/')
          # Find which taskrunner this belongs to
          local found_runner=""
          for r in "${LOADED_TASKRUNNERS[@]:-}"; do
            local r_label
            r_label=$(get_taskrunner_label "$r")
            if [[ "$r_label" == "$divider_label" ]]; then
              found_runner="$r"
              break
            fi
          done
          if [[ -n "$found_runner" ]]; then
            # Give divider the same order as its taskrunner, but *10-1 to appear before items
            local base_order
            base_order=$(get_item_order "taskrunner:$found_runner")
            order_keys+=("$((base_order * 10 - 1))")
          else
            order_keys+=("99980")
          fi
          continue
        fi

        # Map to config item key
        local config_key
        local order
        if [[ "$item_name" == menu:* || "$item_name" == dirbrowser:* ]]; then
          # Already has prefix
          config_key="$item_name"
          order=$(get_item_order "$config_key")
          order_keys+=("$((order * 10))")
        elif [[ "$item_name" == *:* ]]; then
          # Could be taskrunner (runner:item) - check first part
          local prefix="${item_name%%:*}"
          local found=false
          for r in "${LOADED_TASKRUNNERS[@]:-}"; do
            if [[ "$r" == "$prefix" ]]; then
              config_key="taskrunner:$prefix"
              found=true
              break
            fi
          done
          if [[ "$found" == "true" ]]; then
            order=$(get_item_order "$config_key")
            order_keys+=("$((order * 10))")
          else
            # Unknown prefix - treat as app
            config_key="app:$item_name"
            order=$(get_item_order "$config_key")
            order_keys+=("$((order * 10))")
          fi
        else
          # Plain name - it's an app
          config_key="app:$item_name"
          order=$(get_item_order "$config_key")
          order_keys+=("$((order * 10))")
        fi
      done < <("$builder" "$current_menu")
    fi
  done

  # Sort lines by order and output
  if [[ ${#menu_lines[@]} -eq 0 ]]; then
    return
  fi

  # Create array of "order:index" for sorting
  local -a sort_pairs=()
  local i
  for i in "${!menu_lines[@]}"; do
    sort_pairs+=("${order_keys[$i]}:$i")
  done

  # Sort by order (numeric)
  local sorted
  sorted=$(printf '%s\n' "${sort_pairs[@]}" | sort -t: -k1 -n)

  # Output in sorted order
  while IFS=: read -r _order idx; do
    echo "${menu_lines[$idx]}"
  done <<<"$sorted"
}

# Launch: try each module until one handles it
dispatch_launch() {
  local name="$1"
  shift
  for mod in "${LOADED_MODULES[@]}"; do
    local launcher="${mod}_launch"
    if [[ $(type -t "$launcher") == "function" ]]; then
      "$launcher" "$name" "$@" && return 0
    fi
  done
  return 1
}

# Get current pane's working directory
get_current_dir() {
  tmux display-message -p '#{pane_current_path}' 2>/dev/null || pwd
}

# Nunchucks ASCII art (used in easter egg and error displays)
read -r -d '' NUNCHUCKS_ART <<'EOF' || true
.-o-o-o-o-o-o-o-.
/                 \\
[O]                 [O]
|=|                 |=|
| |                   | |
| |                   | |
| |                     | |
| |                     | |
|=|                       |=|
|_|                       |_|
EOF

# Easter egg: Chuck Norris programming facts
CHUCK_FACTS=(
  "Chuck Norris can unit test entire applications with a single assert."
  "Chuck Norris doesn't use web frameworks. The internet obeys him."
  "Chuck Norris can delete the root folder and still boot."
  "Chuck Norris's code doesn't follow conventions. Conventions follow his code."
  "Chuck Norris can instantiate an abstract class."
  "Chuck Norris doesn't need sudo. The system always trusts him."
  "Chuck Norris can divide by zero."
  "When Chuck Norris throws an exception, nothing can catch it."
  "Chuck Norris's keyboard doesn't have a Ctrl key. He's always in control."
  "Chuck Norris can compile syntax errors."
  "Chuck Norris doesn't need garbage collection. Memory is too afraid to leak."
  "Chuck Norris can read from /dev/null."
  "Chuck Norris finished World of Warcraft."
  "Chuck Norris can write infinite loops that finish in under 2 seconds."
  "Chuck Norris's code is self-documenting. In binary."
  "Chuck Norris doesn't pair program. The code pairs with him."
  "When Chuck Norris git pushes, the remote pulls."
  "Chuck Norris can access private methods. Publicly."
  "Chuck Norris doesn't get compiler errors. The compiler gets Chuck Norris errors."
  "Chuck Norris can make a class that is both abstract and final."
)

# vim: ft=bash ts=2 sw=2 et
