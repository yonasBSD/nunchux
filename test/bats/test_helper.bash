#!/usr/bin/env bash
#
# test_helper.bash - Shared setup for BATS tests
#

# Get the absolute path to the nunchux root directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NUNCHUX_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# Temporary directory for test isolation
TEMP_DIR=""

# Mock tmux command - accepts all commands, returns success
tmux() {
  case "$1" in
  set-environment)
    # Accept and ignore
    return 0
    ;;
  display-message)
    # Return fake pane path
    echo "/tmp/test-pane-path"
    ;;
  list-windows)
    # Return empty - no windows running
    echo ""
    ;;
  display-popup | run-shell)
    # Accept and ignore
    return 0
    ;;
  *)
    # Default: accept and ignore
    return 0
    ;;
  esac
}
export -f tmux

# Setup function - called before each test
setup() {
  # Create temp directory for test isolation
  TEMP_DIR="$(mktemp -d)"

  # Reset module state by unsetting loaded flags
  unset NUNCHUX_LIB_CORE_LOADED
  unset NUNCHUX_LIB_CONFIG_LOADED
  unset NUNCHUX_LIB_UTILS_LOADED
  unset NUNCHUX_LIB_CACHE_LOADED
  unset NUNCHUX_LIB_MENU_LOADED
  unset NUNCHUX_LIB_MIGRATE_LOADED
  unset NUNCHUX_MOD_APP_LOADED
  unset NUNCHUX_MOD_DIRBROWSER_LOADED
  unset NUNCHUX_MOD_MENU_LOADED
  unset NUNCHUX_MOD_TASKRUNNER_LOADED

  # Reset config state
  unset NUNCHUX_RC_FILE_EXPLICIT

  # Source core library (which loads all other libs)
  source "$NUNCHUX_ROOT/lib/core.sh"
}

# Teardown function - called after each test
teardown() {
  # Clean up temp directory
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi

  # Return to original directory
  cd "$TEST_DIR"
}

# Helper: Load modules and parse config for current directory
load_and_parse_config() {
  load_modules
  local config_file
  config_file=$(get_config_file)
  if [[ -n "$config_file" ]]; then
    parse_config "$config_file"
  fi
  load_taskrunners
}

# Helper: Assert output contains string
assert_output_contains() {
  local expected="$1"
  if [[ "$output" != *"$expected"* ]]; then
    echo "Expected output to contain: $expected"
    echo "Actual output: $output"
    return 1
  fi
}

# Helper: Assert output does not contain string
assert_output_not_contains() {
  local unexpected="$1"
  if [[ "$output" == *"$unexpected"* ]]; then
    echo "Expected output to NOT contain: $unexpected"
    echo "Actual output: $output"
    return 1
  fi
}

# Helper: Assert file exists
assert_file_exists() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "Expected file to exist: $file"
    return 1
  fi
}

# Helper: Count lines in output
count_output_lines() {
  echo "$output" | wc -l | tr -d ' '
}

# Helper: Get specific line from output
get_output_line() {
  local line_num="$1"
  echo "$output" | sed -n "${line_num}p"
}

# Helper: Create a minimal test config
create_test_config() {
  local dir="$1"
  local content="$2"
  mkdir -p "$dir"
  echo "$content" >"$dir/.nunchuxrc"
}

# vim: ft=bash ts=2 sw=2 et
