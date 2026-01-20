#!/usr/bin/env bash
# Test: Blocked config is skipped (automated)
# Verifies that configs in blocked_configs are not loaded

source "${BASH_SOURCE%/*}/../test_helpers.sh"

echo "(automated - checking blocked config behavior)"

# Get the state directory
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nunchux"
BLOCKED_FILE="$STATE_DIR/blocked_configs"

# Get absolute path to our test config
CONFIG_PATH="$(cd "$TEST_DIR" && pwd)/.nunchuxrc"

# Backup existing blocked file if any
if [[ -f "$BLOCKED_FILE" ]]; then
  cp "$BLOCKED_FILE" "$BLOCKED_FILE.bak"
fi

# Add our test config to blocked list
mkdir -p "$STATE_DIR"
echo "$CONFIG_PATH" >> "$BLOCKED_FILE"

# Get menu output - should NOT contain blocked-app
menu=$(get_menu)

# Restore original blocked file
if [[ -f "$BLOCKED_FILE.bak" ]]; then
  mv "$BLOCKED_FILE.bak" "$BLOCKED_FILE"
else
  # Remove only our entry
  grep -v "^$CONFIG_PATH$" "$BLOCKED_FILE" > "$BLOCKED_FILE.tmp" 2>/dev/null || true
  mv "$BLOCKED_FILE.tmp" "$BLOCKED_FILE" 2>/dev/null || rm -f "$BLOCKED_FILE"
fi

# Check result
if echo "$menu" | grep -q "blocked-app"; then
  fail "blocked config was loaded (should have been skipped)"
else
  pass "blocked config correctly skipped"
fi
