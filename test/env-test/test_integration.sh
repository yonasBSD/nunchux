#!/usr/bin/env bash
#
# test_integration.sh - Integration test for environment variable inheritance
#
# This test verifies that environment variables from the parent shell are
# correctly inherited when launching apps in both popup and window modes.
#
# It creates a dedicated tmux session, installs shell hooks, exports a test
# variable, and uses tmux send-keys to interact with fzf to select test apps.
#
# Requirements:
# - Must be run from the nunchux repository root
# - tmux must be available
# - fzf must be available

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NUNCHUX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
NUNCHUX_BIN="$NUNCHUX_ROOT/bin/nunchux"
SHELL_INIT="$NUNCHUX_ROOT/shell-init.bash"
TEST_CONFIG="$SCRIPT_DIR/.nunchuxrc"

# Test session name (unique per run)
SESSION="nunchux-test-$$"

# Output files from test apps
POPUP_OUTPUT="/tmp/nunchux-integration-popup"
WINDOW_OUTPUT="/tmp/nunchux-integration-window"

# Test variable
TEST_VAR_NAME="NUNCHUX_INTEGRATION_TEST"
TEST_VAR_VALUE="test_value_$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; FAILED=1; }
info() { echo -e "${YELLOW}→${NC} $1"; }

FAILED=0

# Cleanup function - always runs on exit
cleanup() {
  info "Cleaning up..."

  # Kill test session if it exists
  tmux kill-session -t "$SESSION" 2>/dev/null || true

  # Remove output files
  rm -f "$POPUP_OUTPUT" "$WINDOW_OUTPUT" 2>/dev/null || true

  if [[ $FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
  else
    echo -e "\n${RED}Some tests failed.${NC}"
  fi
}
trap cleanup EXIT

# Wait for a file to appear with timeout
wait_for_file() {
  local file="$1"
  local timeout="${2:-10}"
  local elapsed=0

  while [[ ! -f "$file" ]] && [[ $elapsed -lt $timeout ]]; do
    sleep 0.2
    elapsed=$((elapsed + 1))
  done

  [[ -f "$file" ]]
}

# Wait for fzf to be ready (check for menu items in session)
wait_for_fzf() {
  local timeout="${1:-5}"
  local elapsed=0

  while [[ $elapsed -lt $timeout ]]; do
    # Check if fzf is running by looking for menu items or fzf prompt
    if tmux capture-pane -t "$SESSION" -p 2>/dev/null | grep -qE "(env-popup|env-window|▶|>)"; then
      return 0
    fi
    sleep 0.2
    elapsed=$((elapsed + 1))
  done

  return 1
}

# Debug: show pane contents on failure
show_debug_info() {
  echo ""
  echo "=== Debug: Pane contents ==="
  tmux capture-pane -t "$SESSION" -p 2>/dev/null || echo "(could not capture pane)"
  echo "=== End debug ==="
}

echo "=== Environment Inheritance Integration Test ==="
echo ""
echo "Test ID: $$"
echo "Session: $SESSION"
echo ""

# Verify prerequisites
if ! command -v tmux &>/dev/null; then
  echo "Error: tmux is required but not installed."
  exit 1
fi

if ! command -v fzf &>/dev/null; then
  echo "Error: fzf is required but not installed."
  exit 1
fi

if [[ ! -f "$NUNCHUX_BIN" ]]; then
  echo "Error: nunchux not found at $NUNCHUX_BIN"
  echo "Please run this test from the nunchux repository root."
  exit 1
fi

if [[ ! -f "$SHELL_INIT" ]]; then
  echo "Error: shell-init.bash not found at $SHELL_INIT"
  exit 1
fi

# Clean up any leftover output files
rm -f "$POPUP_OUTPUT" "$WINDOW_OUTPUT" 2>/dev/null || true

# =============================================================================
# Setup: Create test tmux session with shell hooks
# =============================================================================

info "Creating test tmux session..."
tmux new-session -d -s "$SESSION" -x 120 -y 30
sleep 0.3

# Get the target pane (handles different base-index settings)
TARGET="$SESSION"

info "Installing shell hooks..."
tmux send-keys -t "$TARGET" "source '$SHELL_INIT'" Enter
sleep 0.3

info "Exporting test variable: $TEST_VAR_NAME=$TEST_VAR_VALUE"
tmux send-keys -t "$TARGET" "export $TEST_VAR_NAME='$TEST_VAR_VALUE'" Enter
sleep 0.3

# Trigger the shell hook to save the environment
info "Triggering shell hook to save environment..."
tmux send-keys -t "$TARGET" "true" Enter
sleep 0.5

# Verify env file was created
pane_id=$(tmux display-message -t "$TARGET" -p '#{pane_id}')
env_file="/tmp/nunchux-env-$pane_id"
if [[ -f "$env_file" ]]; then
  pass "Shell hook created env file: $env_file"
else
  fail "Shell hook did not create env file"
  show_debug_info
  exit 1
fi

# Set NUNCHUX_ENV_FILE in tmux environment (normally done by keybinding)
info "Setting NUNCHUX_ENV_FILE in tmux environment..."
tmux set-environment -t "$SESSION" NUNCHUX_ENV_FILE "$env_file"
tmux set-environment -t "$SESSION" NUNCHUX_PARENT_PANE "$pane_id"

# =============================================================================
# Test 1: Popup mode
# =============================================================================

echo ""
echo "--- Test 1: Popup Mode ---"

info "Launching nunchux..."
tmux send-keys -t "$TARGET" "cd '$SCRIPT_DIR' && NUNCHUX_RC_FILE='$TEST_CONFIG' '$NUNCHUX_BIN'" Enter

# Wait for fzf to appear
if ! wait_for_fzf 5; then
  fail "fzf did not appear within timeout"
  show_debug_info
  exit 1
fi
sleep 0.3

info "Filtering for 'env-popup'..."
tmux send-keys -t "$TARGET" "env-popup"
sleep 0.3

info "Pressing Enter to open in popup..."
tmux send-keys -t "$TARGET" Enter

# Wait for output file
info "Waiting for popup to write output file..."
if wait_for_file "$POPUP_OUTPUT" 10; then
  pass "Popup wrote output file"

  # Verify the test variable is present
  if grep -q "$TEST_VAR_NAME=$TEST_VAR_VALUE" "$POPUP_OUTPUT"; then
    pass "Popup inherited $TEST_VAR_NAME correctly"
  else
    fail "Popup did NOT inherit $TEST_VAR_NAME"
    echo "    Expected: $TEST_VAR_NAME=$TEST_VAR_VALUE"
    echo "    Contents of $POPUP_OUTPUT:"
    grep "$TEST_VAR_NAME" "$POPUP_OUTPUT" 2>/dev/null || echo "    (variable not found)"
  fi
else
  fail "Popup output file not created within timeout"
  show_debug_info
fi

# Clean up for next test
rm -f "$POPUP_OUTPUT" 2>/dev/null || true
sleep 0.5

# =============================================================================
# Test 2: Window mode
# =============================================================================

echo ""
echo "--- Test 2: Window Mode ---"

info "Launching nunchux..."
tmux send-keys -t "$TARGET" "cd '$SCRIPT_DIR' && NUNCHUX_RC_FILE='$TEST_CONFIG' '$NUNCHUX_BIN'" Enter

# Wait for fzf to appear
if ! wait_for_fzf 5; then
  fail "fzf did not appear within timeout"
  show_debug_info
  exit 1
fi
sleep 0.3

info "Filtering for 'env-window'..."
tmux send-keys -t "$TARGET" "env-window"
sleep 0.3

info "Pressing Ctrl-O to open in window..."
tmux send-keys -t "$TARGET" C-o

# Wait for output file
info "Waiting for window to write output file..."
if wait_for_file "$WINDOW_OUTPUT" 10; then
  pass "Window wrote output file"

  # Verify the test variable is present
  if grep -q "$TEST_VAR_NAME=$TEST_VAR_VALUE" "$WINDOW_OUTPUT"; then
    pass "Window inherited $TEST_VAR_NAME correctly"
  else
    fail "Window did NOT inherit $TEST_VAR_NAME"
    echo "    Expected: $TEST_VAR_NAME=$TEST_VAR_VALUE"
    echo "    Contents of $WINDOW_OUTPUT:"
    grep "$TEST_VAR_NAME" "$WINDOW_OUTPUT" 2>/dev/null || echo "    (variable not found)"
  fi

  # Close the test window
  info "Closing test window..."
  tmux kill-window -t "$SESSION:env-window" 2>/dev/null || true
else
  fail "Window output file not created within timeout"
  show_debug_info
fi

echo ""
echo "=== Test Summary ==="

# vim: ft=bash ts=2 sw=2 et
