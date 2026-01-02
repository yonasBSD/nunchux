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

# Load nunchux-run for nunchux_launch function
source "$NUNCHUX_BIN_DIR/nunchux-run"

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

# Get sort key for an item based on [order] sections
# Returns: position in MAIN_ORDER (0-based), or 10000+alpha_position for unlisted items
_get_order_key() {
  local item="$1"
  local i

  # Check if item is in MAIN_ORDER
  for i in "${!MAIN_ORDER[@]}"; do
    if [[ "${MAIN_ORDER[$i]}" == "$item" ]]; then
      echo "$i"
      return
    fi
  done

  # Not in MAIN_ORDER - return high number for alphabetical sorting later
  echo "10000"
}


# Build combined menu from all modules (sorted by [order] sections)
build_combined_menu() {
  local current_menu="${1:-}"
  local -a menu_lines=()
  local -a item_names=()   # For sorting unlisted items alphabetically

  # Collect output from all modules
  for mod in "${LOADED_MODULES[@]}"; do
    local builder="${mod}_build_menu"
    if [[ $(type -t "$builder") == "function" ]]; then
      while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        menu_lines+=("$line")

        # Extract item name for sorting (field 3 after shortcut field)
        local item_name
        item_name=$(printf '%s' "$line" | cut -f3)
        item_names+=("$item_name")
      done < <("$builder" "$current_menu")
    fi
  done

  if [[ ${#menu_lines[@]} -eq 0 ]]; then
    return
  fi

  # Build sort keys for each line
  local -a order_keys=()
  local -a alpha_keys=()
  local i
  for i in "${!menu_lines[@]}"; do
    local line="${menu_lines[$i]}"
    local item_name="${item_names[$i]}"

    # Check if this is a divider line (taskrunner section header)
    if [[ "$line" == *"───"* ]]; then
      # Parse runner name from divider
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
        local runner_order
        runner_order=$(_get_order_key "taskrunner:$found_runner")
        # Taskrunners default to 20000 (below apps/menus/dirbrowsers at 10000)
        [[ "$runner_order" == "10000" ]] && runner_order=20000
        # Same order as items; alpha "runner" < "runner:task" so divider comes first
        order_keys+=("$((runner_order * 100))")
        alpha_keys+=("$found_runner")
      else
        order_keys+=("999999")
        alpha_keys+=("zzz")
      fi
      continue
    fi

    # Determine item identifier for ordering
    local order_name=""
    if [[ "$item_name" == menu:* ]]; then
      order_name="${item_name#menu:}"
      local order_key
      order_key=$(_get_order_key "$order_name")
      order_keys+=("$((order_key * 100))")
      alpha_keys+=("$order_name")
    elif [[ "$item_name" == dirbrowser:* ]]; then
      order_name="${item_name#dirbrowser:}"
      local order_key
      order_key=$(_get_order_key "$order_name")
      order_keys+=("$((order_key * 100))")
      alpha_keys+=("$order_name")
    elif [[ "$item_name" == *:* ]]; then
      # Could be taskrunner item (runner:task)
      local prefix="${item_name%%:*}"
      local is_taskrunner=false
      for r in "${LOADED_TASKRUNNERS[@]:-}"; do
        if [[ "$r" == "$prefix" ]]; then
          is_taskrunner=true
          break
        fi
      done
      if [[ "$is_taskrunner" == "true" ]]; then
        # Taskrunner item - sort by runner order (lookup taskrunner:$runner in MAIN_ORDER)
        local runner_order
        runner_order=$(_get_order_key "taskrunner:$prefix")
        # Taskrunners default to 20000 (below apps/menus/dirbrowsers at 10000)
        [[ "$runner_order" == "10000" ]] && runner_order=20000
        order_keys+=("$((runner_order * 100))")
        # Use full item name (runner:task) to keep same-runner tasks grouped
        alpha_keys+=("$item_name")
      else
        # Regular app with / in name (submenu child)
        order_name="$item_name"
        local order_key
        order_key=$(_get_order_key "$order_name")
        order_keys+=("$((order_key * 100))")
        alpha_keys+=("$order_name")
      fi
    else
      # Plain app name
      order_name="$item_name"
      local order_key
      order_key=$(_get_order_key "$order_name")
      order_keys+=("$((order_key * 100))")
      alpha_keys+=("$order_name")
    fi
  done

  # Create array of "order\talpha\tindex" for sorting (tab-delimited to avoid : in names)
  local -a sort_pairs=()
  for i in "${!menu_lines[@]}"; do
    sort_pairs+=("${order_keys[$i]}"$'\t'"${alpha_keys[$i]}"$'\t'"$i")
  done

  # Sort by order (numeric), then by alpha (for unlisted items)
  local sorted
  sorted=$(printf '%s\n' "${sort_pairs[@]}" | sort -t$'\t' -k1,1n -k2,2)

  # Output in sorted order
  while IFS=$'\t' read -r _order _alpha idx; do
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
