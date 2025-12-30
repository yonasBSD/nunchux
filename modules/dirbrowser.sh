#!/usr/bin/env bash
#
# modules/dirbrowser.sh - Directory browser handling
#
# Config format:
#   [dirbrowser:configs]
#   directory = ~/.config
#   depth = 2
#   sort = modified-folder
#   sort_direction = descending
#   glob = *.conf
#   cache_ttl = 300
#   width = 90
#   height = 80
#

# Guard against double-sourcing
[[ -n "${NUNCHUX_MOD_DIRBROWSER_LOADED:-}" ]] && return
NUNCHUX_MOD_DIRBROWSER_LOADED=1

# Directory browser storage (declare -g for global scope when sourced from function)
declare -gA DIRBROWSE_DIR=()
declare -gA DIRBROWSE_DEPTH=()
declare -gA DIRBROWSE_WIDTH=()
declare -gA DIRBROWSE_HEIGHT=()
declare -gA DIRBROWSE_GLOB=()
declare -gA DIRBROWSE_SORT=()
declare -gA DIRBROWSE_SORT_DIR=()
declare -gA DIRBROWSE_CACHE_TTL=()
declare -ga DIRBROWSE_ORDER=()

# Register with core
register_module "dirbrowser"

# Parse a config section for a directory browser
# Called by config parser when [dirbrowser:name] is encountered
dirbrowser_parse_section() {
  local name="$1"
  local data_decl="$2"

  # Temporarily disable set -u for associative array access
  set +u

  # Reconstruct associative array from declaration
  eval "$data_decl"

  # Store dirbrowser configuration
  local dir="${section_data[directory]:-}"
  DIRBROWSE_DIR["$name"]="${dir/#\~/$HOME}"
  DIRBROWSE_DEPTH["$name"]="${section_data[depth]:-1}"
  DIRBROWSE_WIDTH["$name"]="${section_data[width]:-90}"
  DIRBROWSE_HEIGHT["$name"]="${section_data[height]:-80}"
  DIRBROWSE_GLOB["$name"]="${section_data[glob]:-}"
  DIRBROWSE_SORT["$name"]="${section_data[sort]:-modified}"
  DIRBROWSE_SORT_DIR["$name"]="${section_data[sort_direction]:-descending}"
  DIRBROWSE_CACHE_TTL["$name"]="${section_data[cache_ttl]:-300}"

  # Parse order property
  local _order="${section_data[order]:-}"

  set -u

  DIRBROWSE_ORDER+=("$name")

  # Track in global order with optional explicit order
  track_config_item "dirbrowser:$name" "$_order"
}

# Build menu entries for directory browsers
# Only shown in main menu (when current_menu is empty)
dirbrowser_build_menu() {
  local current_menu="${1:-}"

  # Directory browsers only appear in main menu
  [[ -n "$current_menu" ]] && return

  for name in "${DIRBROWSE_ORDER[@]}"; do
    local dir="${DIRBROWSE_DIR[$name]:-}"
    [[ -z "$dir" ]] && continue

    local file_count
    # Use a subshell to avoid SIGPIPE issues with pipefail
    file_count=$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')
    [[ "$file_count" -gt 1000 ]] && file_count="1000+"

    # Format: visible_part \t name \t (empty fields)
    # Use dirbrowser: prefix to identify
    printf "▸  %-12s  (%s files)\t%s\t\t\t\t\n" "$name" "$file_count" "dirbrowser:$name"
  done
}

# Launch (enter) a directory browser
# Returns 0 if handled, 1 if not our item
dirbrowser_launch() {
  local name="$1"
  local key="$2"

  # Check if this is a dirbrowser reference
  [[ "$name" != dirbrowser:* ]] && return 1

  local browser_name="${name#dirbrowser:}"

  # Easter egg: secondary key on dirbrowser
  if [[ "$key" == "$SECONDARY_KEY" ]]; then
    show_chuck_easter_egg
    return 0
  fi

  # Launch the directory browser
  launch_dirbrowse "$browser_name"

  return 0
}

# Build directory browser file list
build_dirbrowse_menu() {
  local name="$1"
  local dir="${DIRBROWSE_DIR[$name]}"
  local depth="${DIRBROWSE_DEPTH[$name]:-1}"
  local glob_pattern="${DIRBROWSE_GLOB[$name]:-}"
  local width="${DIRBROWSE_WIDTH[$name]:-90}"
  local height="${DIRBROWSE_HEIGHT[$name]:-80}"
  local sort_mode="${DIRBROWSE_SORT[$name]:-modified}"
  local sort_dir="${DIRBROWSE_SORT_DIR[$name]:-descending}"

  # Build find command with depth and exclusions
  local find_args=()
  find_args+=("$dir" -maxdepth "$depth" -type f)

  # Apply exclusion patterns from config
  IFS=',' read -ra exclude_patterns <<<"$EXCLUDE_PATTERNS"
  for pattern in "${exclude_patterns[@]}"; do
    # Trim whitespace
    pattern="${pattern#"${pattern%%[![:space:]]*}"}"
    pattern="${pattern%"${pattern##*[![:space:]]}"}"
    [[ -z "$pattern" ]] && continue

    if [[ "$pattern" == \** ]]; then
      # Glob pattern - match filename only
      find_args+=(! -name "$pattern")
    else
      # Directory/file name - exclude both paths containing it and files named it
      find_args+=(! -path "*/$pattern/*" ! -name "$pattern")
    fi
  done

  # Apply glob filter if specified
  if [[ -n "$glob_pattern" ]]; then
    find_args+=(-name "$glob_pattern")
  fi

  local now
  now=$(date +%s)

  # Set sort direction flag
  local sort_flag=""
  [[ "$sort_dir" == "descending" ]] && sort_flag="-r"

  # Generate sorted file list based on sort mode
  local sorted_files
  case "$sort_mode" in
  alphabetical)
    sorted_files=$(find_with_mtime "${find_args[@]}" | awk -F'\t' -v dir="$dir" '
            {
                mtime = $1
                file = $2
                rel = file
                sub("^" dir "/", "", rel)
                split(rel, parts, "/")
                folder = parts[1]
                print rel "\t" mtime "\t" folder "\t" file
            }
            ' | sort -t$'\t' -k1 $sort_flag)
    ;;
  modified-folder)
    sorted_files=$(find_with_mtime "${find_args[@]}" | awk -F'\t' -v dir="$dir" '
            {
                mtime = $1
                file = $2
                rel = file
                sub("^" dir "/", "", rel)
                split(rel, parts, "/")
                folder = parts[1]
                if (!(folder in folder_max) || mtime > folder_max[folder]) {
                    folder_max[folder] = mtime
                }
                files[NR] = mtime "\t" folder "\t" file
                count = NR
            }
            END {
                for (i = 1; i <= count; i++) {
                    split(files[i], f, "\t")
                    print folder_max[f[2]] "\t" f[1] "\t" f[2] "\t" f[3]
                }
            }
            ' | sort -t$'\t' -k1 ${sort_flag}n -k2 ${sort_flag}n)
    ;;
  modified | *)
    sorted_files=$(find_with_mtime "${find_args[@]}" | awk -F'\t' -v dir="$dir" '
            {
                mtime = $1
                file = $2
                rel = file
                sub("^" dir "/", "", rel)
                split(rel, parts, "/")
                folder = parts[1]
                print mtime "\t" mtime "\t" folder "\t" file
            }
            ' | sort -t$'\t' -k1 ${sort_flag}n)
    ;;
  esac

  # Format output
  echo "$sorted_files" | while IFS=$'\t' read -r _sort_key mtime folder file; do
    [[ -z "$file" ]] && continue

    # Get folder/filename display with folder colored
    local filename display
    filename=$(basename "$file")
    if [[ "$folder" == "$filename" ]]; then
      display="$filename"
    else
      # Color folder in muted gray
      display=$'\033[38;5;244m'"$folder/"$'\033[0m'"$filename"
    fi

    # Calculate ago from mtime
    local secs=$((now - ${mtime%%.*}))
    local modified
    modified=$(format_ago "$secs")

    # Format: visible_part \t full_path \t width \t height
    printf "○  %8s │ %s\t%s\t%s\t%s\n" "$modified" "$display" "$file" "$width" "$height"
  done
}

# Launch directory browser with fzf
launch_dirbrowse() {
  local name="$1"
  local width="${DIRBROWSE_WIDTH[$name]:-90}"
  local height="${DIRBROWSE_HEIGHT[$name]:-80}"
  local cache_ttl="${DIRBROWSE_CACHE_TTL[$name]:-300}"
  [[ "$width" =~ ^[0-9]+$ ]] && width="${width}%"
  [[ "$height" =~ ^[0-9]+$ ]] && height="${height}%"

  local cache_file socket selection
  cache_file=$(cache_file "dirbrowser" "$name")
  socket=$(cache_socket "dirbrowser" "$name")

  # Build fzf options
  local fzf_opts
  local primary_display="${PRIMARY_KEY^}"
  local secondary_display="${SECONDARY_KEY^}"
  build_fzf_opts fzf_opts "$primary_display: edit | $secondary_display: window | Esc: back"
  fzf_opts+=(--ansi)

  # Check if we have a valid cache
  if is_cache_valid "$cache_file" "$cache_ttl"; then
    # Cache is valid - load instantly and refresh in background
    refresh_cache "$cache_file" "$socket" build_dirbrowse_menu "$name" &
    local refresh_pid=$!

    selection=$(cat "$cache_file" | fzf "${fzf_opts[@]}" --listen "$socket") || true

    kill $refresh_pid 2>/dev/null || true
    rm -f "$socket" 2>/dev/null || true
  else
    # No valid cache - stream to fzf AND save to cache via tee
    selection=$(build_dirbrowse_menu "$name" | tee "$cache_file" | fzf "${fzf_opts[@]}") || true
  fi

  if [[ -z "$selection" ]]; then
    # Go back to main menu - signal to caller
    return 2
  fi

  # Parse fzf output
  local key selected_line
  key=$(echo "$selection" | head -1)
  selected_line=$(echo "$selection" | tail -1)

  if [[ -z "$selected_line" ]]; then
    return 2
  fi

  # Extract file path
  local file_path
  file_path=$(echo "$selected_line" | cut -f2)

  if [[ -n "$file_path" && -f "$file_path" ]]; then
    local editor="${VISUAL:-${EDITOR:-nvim}}"
    local file_basename
    file_basename=$(basename "$file_path")

    if [[ "$key" == "$SECONDARY_KEY" ]]; then
      # Open in new tmux window with parent environment
      local dir
      dir=$(dirname "$file_path")
      tmux new-window -n "$file_basename" -c "$dir" "$NUNCHUX_BIN_DIR/nunchux-run" "$editor" "$file_path"
    else
      # Open in editor popup with parent environment
      tmux run-shell -b "sleep 0.05; tmux display-popup -E -b rounded -T ' $name: $file_basename ' -w $width -h $height '$NUNCHUX_BIN_DIR/nunchux-run' '$editor' '$file_path'"
      exit 0
    fi
  fi
}

# Check if we have any dirbrowsers configured
dirbrowser_has_items() {
  [[ ${#DIRBROWSE_ORDER[@]} -gt 0 ]]
}

# vim: ft=bash ts=2 sw=2 et
