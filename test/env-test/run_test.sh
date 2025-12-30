#!/usr/bin/env bash
#
# run_test.sh - Integration test for environment variable inheritance
#
# This test demonstrates that environment variables set in the parent
# shell ARE passed through to apps launched via nunchux popups.
#
# Usage:
#   1. Run this script inside tmux: ./test/env-test/run_test.sh
#   2. Select "printenv" from the menu
#   3. Observe that NUNCHUX_TEST_VAR IS found (fix is working!)
#
# Note: You must reload tmux config first to get the new keybinding:
#   tmux source-file ~/.tmux.conf

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NUNCHUX_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Check we're in tmux
if [[ -z "${TMUX:-}" ]]; then
  echo "Error: This test must be run inside tmux."
  echo ""
  echo "Start tmux first, then run:"
  echo "  $0"
  exit 1
fi

echo "=== Nunchux Environment Variable Test ==="
echo ""
echo "This test checks if environment variables from your shell"
echo "are passed through to apps launched in nunchux popups."
echo ""

# Set test environment variables (simulating nvm, pyenv, etc.)
export NUNCHUX_TEST_VAR="hello_from_parent_shell"
export PATH="/fake/nvm/path:$PATH"

echo "Setting test variables in this shell:"
echo "  NUNCHUX_TEST_VAR=$NUNCHUX_TEST_VAR"
echo "  PATH now includes: /fake/nvm/path"
echo ""
echo "Launching nunchux... select 'printenv' from the menu."
echo ""
echo "Expected: Both variables should be found (fix is working!)"
echo ""
read -p "Press Enter to launch nunchux..."

# Run nunchux with our test config
cd "$SCRIPT_DIR"
NUNCHUX_RC_FILE="$SCRIPT_DIR/.nunchuxrc" "$NUNCHUX_ROOT/bin/nunchux"

# vim: ft=bash ts=2 sw=2 et
