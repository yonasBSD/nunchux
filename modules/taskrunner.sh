#!/usr/bin/env bash
#
# modules/taskrunner.sh - Task runner integration (just, npm, task, etc.)
#
# Config format:
#   [taskrunner:just]
#   enabled = true
#   icon = 🤖
#   label = just
#
# Task runners are disabled by default. Enable explicitly in config.
#

# Guard against double-sourcing
[[ -n "${NUNCHUX_MOD_TASKRUNNER_LOADED:-}" ]] && return
NUNCHUX_MOD_TASKRUNNER_LOADED=1

# Taskrunner storage (declare -g for global scope when sourced from function)
declare -gA TASKRUNNER_ENABLED=()
declare -gA TASKRUNNER_ICON=()
declare -gA TASKRUNNER_LABEL=()
declare -gA TASKRUNNER_PRIMARY_ACTION=()   # Per-taskrunner primary action override
declare -gA TASKRUNNER_SECONDARY_ACTION=() # Per-taskrunner secondary action override
declare -ga TASKRUNNER_ORDER=()

# Taskrunner-specific defaults (different from global app defaults)
TASKRUNNER_DEFAULT_PRIMARY_ACTION="window"
TASKRUNNER_DEFAULT_SECONDARY_ACTION="background_window"

# Helper to safely get taskrunner enabled status
_taskrunner_is_enabled() {
  local name="$1"
  # Check if key exists in array
  for key in "${!TASKRUNNER_ENABLED[@]}"; do
    if [[ "$key" == "$name" ]]; then
      [[ "${TASKRUNNER_ENABLED[$name]}" == "true" ]]
      return
    fi
  done
  return 1
}

# Loaded taskrunner providers
declare -ga LOADED_TASKRUNNERS=()

# Register with core
register_module "taskrunner"

# Parse a config section for a taskrunner
# Called by config parser when [taskrunner:name] is encountered
taskrunner_parse_section() {
  local name="$1"
  local data_decl="$2"

  # Temporarily disable set -u for associative array access
  set +u

  # Reconstruct associative array from declaration
  eval "$data_decl"

  # Store taskrunner configuration
  # Disabled by default - must explicitly enable
  TASKRUNNER_ENABLED["$name"]="${section_data[enabled]:-false}"
  TASKRUNNER_ICON["$name"]="${section_data[icon]:-}"
  TASKRUNNER_LABEL["$name"]="${section_data[label]:-$name}"
  TASKRUNNER_PRIMARY_ACTION["$name"]="${section_data[primary_action]:-}"
  TASKRUNNER_SECONDARY_ACTION["$name"]="${section_data[secondary_action]:-}"

  # Parse order property
  local _order="${section_data[order]:-}"

  set -u

  TASKRUNNER_ORDER+=("$name")

  # Track in global order with optional explicit order
  track_config_item "taskrunner:$name" "$_order"
}

# Load taskrunner providers from taskrunners directory
load_taskrunners() {
  [[ ! -d "$NUNCHUX_TASKRUNNERS_DIR" ]] && return

  for runner_file in "$NUNCHUX_TASKRUNNERS_DIR"/*.sh; do
    [[ -f "$runner_file" ]] || continue

    # Source in subshell to get name
    local name
    name=$(
      source "$runner_file"
      plugin_name
    )

    # Check if enabled in config (default: disabled)
    if ! _taskrunner_is_enabled "$name"; then
      continue
    fi

    # Source and copy functions with namespaced names
    source "$runner_file"
    eval "$(declare -f plugin_items | sed "1s/plugin_items/${name}_items/")"
    eval "$(declare -f plugin_label | sed "1s/plugin_label/${name}_label/")"

    # Icon function is optional
    if declare -f plugin_icon >/dev/null 2>&1; then
      eval "$(declare -f plugin_icon | sed "1s/plugin_icon/${name}_icon/")"
      unset -f plugin_icon
    fi
    unset -f plugin_name plugin_label plugin_items

    LOADED_TASKRUNNERS+=("$name")
  done
}

# Get the icon for a taskrunner
get_taskrunner_icon() {
  local name="$1"

  # Config override takes priority (even if empty)
  if [[ -v TASKRUNNER_ICON[$name] && -n "${TASKRUNNER_ICON[$name]}" ]]; then
    echo "${TASKRUNNER_ICON[$name]}"
    return
  fi

  # Provider-defined icon
  if declare -f "${name}_icon" >/dev/null 2>&1; then
    "${name}_icon"
    return
  fi

  # Fallback to stopped icon
  echo "$ICON_STOPPED"
}

# Get the label for a taskrunner
get_taskrunner_label() {
  local name="$1"
  echo "${TASKRUNNER_LABEL[$name]:-$name}"
}

# Build menu entries for taskrunners
taskrunner_build_menu() {
  local current_menu="${1:-}"

  # Taskrunners only appear in main menu
  [[ -n "$current_menu" ]] && return

  # First pass: collect all data and find max display name width
  local -a runner_data=()
  local max_width=0

  for runner in "${LOADED_TASKRUNNERS[@]}"; do
    local items label
    items=$("${runner}_items")
    [[ -z "$items" ]] && continue

    label=$(get_taskrunner_label "$runner")

    while IFS=$'\t' read -r item cmd desc; do
      [[ -z "$item" ]] && continue
      local display_name="$label $item"
      local width=${#display_name}
      ((width > max_width)) && max_width=$width
      runner_data+=("$runner"$'\t'"$label"$'\t'"$item"$'\t'"$cmd"$'\t'"$desc")
    done <<<"$items"
  done

  # Second pass: output with consistent width
  local current_runner=""
  for entry in "${runner_data[@]}"; do
    IFS=$'\t' read -r runner label item cmd desc <<<"$entry"

    # Print divider with icon when runner changes
    if [[ "$runner" != "$current_runner" ]]; then
      local runner_icon divider_tail content_len tail_len
      runner_icon=$(get_taskrunner_icon "$runner")
      [[ -n "$runner_icon" ]] && runner_icon=" $runner_icon"

      # Calculate trailing dashes to make total length consistent
      content_len=$(printf '%s%s' "$label" "$runner_icon" | wc -L)
      tail_len=$((24 - content_len))
      ((tail_len < 3)) && tail_len=3
      divider_tail=$(printf '─%.0s' $(seq 1 $tail_len))
      local div_prefix
      div_prefix=$(build_shortcut_prefix "")
      printf "%s   ─── %s%s %s\t\t\t\t\t\n" "$div_prefix" "$label" "$runner_icon" "$divider_tail"
      current_runner="$runner"
    fi

    local display_name="$label $item"
    local name="${runner}:${item}"
    local item_prefix
    item_prefix=$(build_shortcut_prefix "")
    printf "%s%s %-${max_width}s  %s\t%s\t%s\t\t\t\n" "$item_prefix" "$ICON_STOPPED" "$display_name" "$desc" "$name" "$cmd"
  done
}

# Launch a taskrunner command
# Returns 0 if handled, 1 if not our item
taskrunner_launch() {
  local name="$1"
  local key="$2"
  local cmd="$3"

  # Check if this is a taskrunner item (format: runner:item)
  [[ "$name" != *:* ]] && return 1

  local runner_prefix="${name%%:*}"
  local is_runner=false
  for r in "${LOADED_TASKRUNNERS[@]}"; do
    [[ "$r" == "$runner_prefix" ]] && {
      is_runner=true
      break
    }
  done

  $is_runner || return 1

  # Get task name for window/popup title (e.g., "just » hello")
  local runner="${name%%:*}"
  local task="${name#*:}"
  local task_name="$runner » $task"
  local dir
  dir=$(get_current_dir)

  # Determine action based on key pressed
  # Taskrunner has its own defaults, but can be overridden per-taskrunner
  local action
  if [[ "$key" == "$SECONDARY_KEY" ]]; then
    action="${TASKRUNNER_SECONDARY_ACTION[$runner]:-$TASKRUNNER_DEFAULT_SECONDARY_ACTION}"
  else
    action="${TASKRUNNER_PRIMARY_ACTION[$runner]:-$TASKRUNNER_DEFAULT_PRIMARY_ACTION}"
  fi

  # Execute the action
  case "$action" in
    popup)
      _taskrunner_open_popup "$task_name" "$cmd" "$dir"
      ;;
    window)
      _taskrunner_open_window "$task_name" "$cmd" "$dir" true
      ;;
    background_window)
      _taskrunner_open_window "$task_name" "$cmd" "$dir" false
      ;;
    *)
      # Unknown action, default to window
      _taskrunner_open_window "$task_name" "$cmd" "$dir" true
      ;;
  esac

  return 0
}

# Open taskrunner in a tmux window
# Args: task_name cmd dir switch_focus
_taskrunner_open_window() {
  local task_name="$1"
  local cmd="$2"
  local dir="$3"
  local switch_focus="$4"

  # Build the command with environment setup, status indicator and wait
  local full_cmd="source '$NUNCHUX_BIN_DIR/nunchux-run'; $cmd"'
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
    tmux rename-window -t "$TMUX_PANE" "'"$task_name"' '"$TASKRUNNER_ICON_SUCCESS"'"
else
    tmux rename-window -t "$TMUX_PANE" "'"$task_name"' '"$TASKRUNNER_ICON_FAILED"'"
fi
echo
echo "Press any key to close..."
read -n 1 -s'

  # Check if window for this task already exists (starts with task_name)
  local existing_window
  existing_window=$(tmux list-windows -F '#{window_id} #{window_name}' | grep -F "$task_name" | head -1 | cut -d' ' -f1)

  # Remember current window
  local current_window
  current_window=$(tmux display-message -p '#{window_id}')

  if [[ -n "$existing_window" ]]; then
    # Reuse existing window - rename and respawn
    tmux rename-window -t "$existing_window" "$task_name $TASKRUNNER_ICON_RUNNING"
    tmux respawn-window -k -t "$existing_window" -c "$dir" bash -c "$full_cmd"
    if [[ "$switch_focus" == "true" ]]; then
      tmux select-window -t "$existing_window"
    else
      tmux select-window -t "$current_window"
    fi
  else
    # Create new window
    if [[ "$switch_focus" == "true" ]]; then
      tmux new-window -n "$task_name $TASKRUNNER_ICON_RUNNING" -c "$dir" bash -c "$full_cmd"
    else
      tmux new-window -d -n "$task_name $TASKRUNNER_ICON_RUNNING" -c "$dir" bash -c "$full_cmd"
    fi
  fi
}

# Open taskrunner in a popup
# Args: task_name cmd dir
_taskrunner_open_popup() {
  local task_name="$1"
  local cmd="$2"
  local dir="$3"

  local script_file="/tmp/nunchux-taskrunner-$$"

  # Build popup script with environment setup and completion handling
  cat >"$script_file" <<NUNCHUX_EOF
#!/usr/bin/env bash

# Apply parent shell environment
source "$NUNCHUX_BIN_DIR/nunchux-run"

cd "$dir"

# Run the task
$cmd
exit_code=\$?

echo
if [[ \$exit_code -eq 0 ]]; then
    echo -e "\033[32m✓ Task completed successfully\033[0m"
else
    echo -e "\033[31m✗ Task failed with exit code \$exit_code\033[0m"
fi
echo
echo "Press any key to close..."
read -n 1 -s

rm -f "$script_file"
NUNCHUX_EOF
  chmod +x "$script_file"

  # Clamp dimensions to max if set
  local width="$APP_POPUP_WIDTH" height="$APP_POPUP_HEIGHT"
  clamp_popup_dimensions width height

  local title=" $NUNCHUX_LABEL: $task_name "
  tmux run-shell -b "sleep 0.05; tmux display-popup -E -b rounded -T '$title' -w '$width' -h '$height' '$script_file'"
  exit 0
}

# Kill a taskrunner window by name (format: runner:task)
# Returns 0 if killed, 1 if not found or not a taskrunner
taskrunner_kill() {
  local name="$1"

  # Check if this looks like a taskrunner item (format: runner:task)
  [[ "$name" != *:* ]] && return 1

  local runner="${name%%:*}"
  local task="${name#*:}"

  # Window name format: "runner » task icon" - match on "runner » task" prefix
  local task_name="$runner » $task"

  # Find window starting with this task name (icon suffix varies)
  local window_id
  window_id=$(tmux list-windows -F '#{window_id} #{window_name}' 2>/dev/null | grep -F "$task_name" | head -1 | cut -d' ' -f1)

  if [[ -n "$window_id" ]]; then
    tmux kill-window -t "$window_id" 2>/dev/null
    return 0
  fi

  return 1
}

# Check if we have any taskrunners loaded
taskrunner_has_items() {
  [[ ${#LOADED_TASKRUNNERS[@]} -gt 0 ]]
}

# vim: ft=bash ts=2 sw=2 et
