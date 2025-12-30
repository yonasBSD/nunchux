#!/usr/bin/env bash
#
# test_fix.sh - Test that the environment inheritance fix works
#
# This test verifies the simplified environment capture mechanism:
# 1. Keybinding sends 'env > /tmp/nunchux-env-<pane_id>' to the pane
# 2. nunchux-run reads NUNCHUX_ENV_FILE from tmux environment
# 3. nunchux-run filters and applies the environment
#
# Works on both Linux and macOS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NUNCHUX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() {
  echo -e "${RED}✗${NC} $1"
  FAILED=1
}
skip() { echo -e "${YELLOW}○${NC} $1 (skipped)"; }

FAILED=0

echo "=== Simplified Environment Fix Tests ==="
echo ""

# Must be in tmux
if [[ -z "${TMUX:-}" ]]; then
  echo "This test must be run inside tmux."
  exit 1
fi

# Simulate what the keybinding does
pane_id=$(tmux display-message -p '#{pane_id}')
env_file="/tmp/nunchux-env-$pane_id"

echo "Test 1: Simulating keybinding env capture"
export NUNCHUX_TEST_VAR="test_value_12345"
export NUNCHUX_TEST_PATH="/fake/nvm/path"
env >"$env_file"
tmux set-environment NUNCHUX_ENV_FILE "$env_file"

if [[ -f "$env_file" ]]; then
  pass "Environment file created at $env_file"
else
  fail "Environment file not created"
  exit 1
fi

echo ""
echo "Test 2: nunchux-run can be sourced"
if bash -c "source '$NUNCHUX_ROOT/bin/nunchux-run'" 2>/dev/null; then
  pass "nunchux-run can be sourced without errors"
else
  fail "nunchux-run has errors when sourced"
fi

echo ""
echo "Test 3: Sourcing nunchux-run applies environment"
# Create a fresh env file since previous test may have consumed it
env >"$env_file"
tmux set-environment NUNCHUX_ENV_FILE "$env_file"

result=$(bash -c "source '$NUNCHUX_ROOT/bin/nunchux-run'; echo \$NUNCHUX_TEST_VAR")
if [[ "$result" == "test_value_12345" ]]; then
  pass "Custom variable restored after sourcing nunchux-run"
else
  fail "Custom variable not restored (got: '$result')"
fi

echo ""
echo "Test 4: nunchux-run cleans up env file after use"
# The previous test should have cleaned up
if [[ ! -f "$env_file" ]]; then
  pass "Env file cleaned up after sourcing"
else
  fail "Env file not cleaned up"
  rm -f "$env_file"
fi

echo ""
echo "Test 5: nunchux-run exec mode works"
# Create fresh env file
export NUNCHUX_EXEC_TEST="exec_mode_works"
env >"$env_file"
tmux set-environment NUNCHUX_ENV_FILE "$env_file"

result=$("$NUNCHUX_ROOT/bin/nunchux-run" bash -c 'echo $NUNCHUX_EXEC_TEST')
if [[ "$result" == "exec_mode_works" ]]; then
  pass "Exec mode applies environment correctly"
else
  fail "Exec mode failed (got: '$result')"
fi

echo ""
echo "Test 6: Problematic variables are filtered"
# Create env file with problematic vars
cat >"$env_file" <<'EOF'
SAFE_VAR=safe_value
BASH_VERSION=should_be_filtered
TMUX=should_be_filtered
SHLVL=should_be_filtered
EOF
tmux set-environment NUNCHUX_ENV_FILE "$env_file"

result=$(bash -c "source '$NUNCHUX_ROOT/bin/nunchux-run'; echo SAFE=\$SAFE_VAR BASH=\$BASH_VERSION")
if [[ "$result" == *"SAFE=safe_value"* ]] && [[ "$result" != *"should_be_filtered"* ]]; then
  pass "Problematic variables filtered, safe ones preserved"
else
  fail "Variable filtering not working correctly"
fi

echo ""
echo "Test 7: Graceful handling when no env file"
tmux set-environment -u NUNCHUX_ENV_FILE 2>/dev/null || true
if bash -c "source '$NUNCHUX_ROOT/bin/nunchux-run'" 2>/dev/null; then
  pass "Gracefully handles missing env file"
else
  fail "Errors when env file missing"
fi

# Cleanup
rm -f "$env_file" 2>/dev/null || true

echo ""
echo "=== Summary ==="
if [[ $FAILED -eq 0 ]]; then
  echo -e "${GREEN}All tests passed!${NC}"
  echo ""
  echo "The simplified architecture:"
  echo "  1. Keybinding runs 'env > file' in the pane"
  echo "  2. nunchux-run reads file path from tmux environment"
  echo "  3. nunchux-run filters and applies env, then cleans up"
  echo "  4. No intermediate processing step needed"
  exit 0
else
  echo -e "${RED}Some tests failed.${NC}"
  exit 1
fi

# vim: ft=bash ts=2 sw=2 et
