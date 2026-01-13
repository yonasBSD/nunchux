#!/usr/bin/env bash
#
# test/test_helpers.sh - Shared helpers for individual test scripts
#
# Sourced by each test folder's test.sh
#

# Determine directories
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
TEST_ROOT="$(cd "$TEST_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$TEST_ROOT/.." && pwd)"
NUNCHUX_BIN="$PROJECT_ROOT/bin/nunchux"
TEST_NAME="$(basename "$TEST_DIR")"

# Find config file
if [[ -f "$TEST_DIR/config" ]]; then
  CONFIG_FILE="$TEST_DIR/config"
else
  CONFIG_FILE="$TEST_DIR/.nunchuxrc"
fi

# Colors (only if stdout is a terminal)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  RESET='\033[0m'
else
  RED=''
  GREEN=''
  RESET=''
fi

# Pass - print message and exit 0
pass() {
  local msg="${1:-test passed}"
  echo -e "${GREEN}[PASS]${RESET} $TEST_NAME: $msg"
  exit 0
}

# Fail - print message and exit 1
fail() {
  local msg="${1:-test failed}"
  echo -e "${RED}[FAIL]${RESET} $TEST_NAME: $msg"
  exit 1
}

# Get menu output from nunchux
get_menu() {
  (cd "$TEST_DIR" && NUNCHUX_RC_FILE="$CONFIG_FILE" NUNCHUX_CWD="$TEST_DIR" "$NUNCHUX_BIN" --menu 2>/dev/null)
}

# Run nunchux with test config (direct - tmux may capture some keys)
run_nunchux() {
  (cd "$TEST_DIR" && NUNCHUX_RC_FILE="$CONFIG_FILE" "$NUNCHUX_BIN" "$@" 2>&1)
}

# Run nunchux in a tmux popup (recommended for keybinding tests)
# This ensures all keys are captured by fzf, not tmux
run_nunchux_popup() {
  local width="${1:-80%}"
  local height="${2:-80%}"
  tmux display-popup -E -w "$width" -h "$height" -d "$TEST_DIR" \
    "NUNCHUX_RC_FILE='$CONFIG_FILE' '$NUNCHUX_BIN'"
}
