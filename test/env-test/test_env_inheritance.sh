#!/usr/bin/env bash
#
# test_env_inheritance.sh - Automated test for environment variable inheritance
#
# This test verifies that environment variables from the parent pane
# are available in popup scripts. It works by:
#   1. Setting a test variable
#   2. Simulating what the popup script would receive
#   3. Checking if the variable is present
#
# This can run outside tmux for unit testing the mechanism.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NUNCHUX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() {
  echo -e "${RED}✗${NC} $1"
  FAILED=1
}
skip() { echo -e "${YELLOW}○${NC} $1 (skipped)"; }

FAILED=0

echo "=== Environment Variable Inheritance Tests ==="
echo ""

# Test 1: Check /proc/<pid>/environ mechanism (Linux only)
echo "Test 1: Reading environment from /proc/<pid>/environ"
if [[ -f /proc/$$/environ ]]; then
  # Note: /proc/$$/environ only contains the INITIAL environment when the shell started,
  # not variables exported later. So we check for a variable that should always exist.
  env_from_proc=$(cat /proc/$$/environ | tr '\0' '\n')

  if echo "$env_from_proc" | grep -q "^PATH="; then
    pass "Can read environment variables from /proc/\$\$/environ"
  else
    fail "Could not find PATH in /proc/\$\$/environ"
  fi
else
  skip "Not on Linux (no /proc filesystem)"
fi

# Test 2: Verify the issue - tmux run-shell doesn't inherit current env
echo ""
echo "Test 2: tmux run-shell environment inheritance"
if [[ -n "${TMUX:-}" ]]; then
  # Set a test variable in current shell
  export NUNCHUX_TEST_VAR_2="from_current_shell_$$"

  # Create a temp file for output
  output_file="/tmp/nunchux-env-test-$$"

  # Run a command via tmux run-shell and capture its environment
  tmux run-shell "env > $output_file"
  sleep 0.2 # Give it time to complete

  if [[ -f "$output_file" ]]; then
    if grep -q "NUNCHUX_TEST_VAR_2=from_current_shell_$$" "$output_file"; then
      pass "tmux run-shell inherits current environment (unexpected!)"
    else
      fail "tmux run-shell does NOT inherit current environment (this is the bug we're fixing)"
      echo "      Variables set in your shell are lost when using tmux run-shell/display-popup"
    fi
    rm -f "$output_file"
  else
    fail "Could not capture tmux run-shell output"
  fi
else
  skip "Not running inside tmux"
fi

# Test 3: Verify pane_pid is accessible
echo ""
echo "Test 3: Access to pane PID for /proc reading"
if [[ -n "${TMUX:-}" ]]; then
  pane_pid=$(tmux display-message -p '#{pane_pid}')
  if [[ -n "$pane_pid" && -d "/proc/$pane_pid" ]]; then
    pass "Can access pane PID ($pane_pid) and its /proc entry exists"

    # Bonus: check if we can read its environ
    if [[ -r "/proc/$pane_pid/environ" ]]; then
      pass "Can read /proc/$pane_pid/environ"
    else
      fail "Cannot read /proc/$pane_pid/environ (permission denied?)"
    fi
  else
    fail "Cannot access pane PID or /proc entry"
  fi
else
  skip "Not running inside tmux"
fi

# Test 4: Verify the fix would work - can we capture and restore env?
echo ""
echo "Test 4: Environment capture and restore mechanism"
if [[ -f /proc/$$/environ ]]; then
  # Use a subshell with its own env to test capture/restore
  # We'll spawn a child, capture ITS env, then verify we can read it back
  env_file="/tmp/nunchux-captured-env-$$"

  # Spawn a child process with known variables, capture its /proc env
  (
    export TEST_CAPTURE_VAR="captured_value_12345"
    # Write our PID so parent can read our /proc environ
    echo $$ >"${env_file}.pid"
    # Sleep briefly so parent can read
    sleep 0.5
  ) &
  child_pid=$!
  sleep 0.1

  # Read the child's environment from /proc
  if [[ -f "/proc/$child_pid/environ" ]]; then
    cat "/proc/$child_pid/environ" | tr '\0' '\n' >"$env_file"
    wait $child_pid 2>/dev/null || true

    if grep -q "TEST_CAPTURE_VAR=captured_value_12345" "$env_file"; then
      pass "Can capture environment from another process via /proc"
    else
      fail "Could not find test variable in captured environment"
    fi
  else
    wait $child_pid 2>/dev/null || true
    fail "Could not access child process /proc environ"
  fi

  rm -f "$env_file" "${env_file}.pid"
else
  skip "Not on Linux (no /proc filesystem)"
fi

echo ""
echo "=== Summary ==="
if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}All applicable tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed.${NC}"
  echo ""
  echo "Note: Test 2 failing is EXPECTED - it demonstrates the bug."
  echo "After implementing the fix, Test 2 should still 'fail' because"
  echo "we can't change how tmux run-shell works, but we work around it"
  echo "by reading from /proc/<pane_pid>/environ."
  exit 1
fi

# vim: ft=bash ts=2 sw=2 et
