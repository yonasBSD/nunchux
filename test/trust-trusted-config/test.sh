#!/usr/bin/env bash
# Test: Trusted config is loaded (automated)
# Verifies that configs in trusted_configs are loaded without prompting

source "${BASH_SOURCE%/*}/../test_helpers.sh"

echo "(automated - checking trusted config behavior)"

# Get the state directory
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/nunchux"
TRUSTED_FILE="$STATE_DIR/trusted_configs"

# Get absolute path to our test config
CONFIG_PATH="$(cd "$TEST_DIR" && pwd)/.nunchuxrc"

# Backup existing trusted file if any
if [[ -f "$TRUSTED_FILE" ]]; then
  cp "$TRUSTED_FILE" "$TRUSTED_FILE.bak"
fi

# Add our test config to trusted list
mkdir -p "$STATE_DIR"
echo "$CONFIG_PATH" >> "$TRUSTED_FILE"

# Get menu output - should contain trusted-app
menu=$(get_menu)

# Restore original trusted file
if [[ -f "$TRUSTED_FILE.bak" ]]; then
  mv "$TRUSTED_FILE.bak" "$TRUSTED_FILE"
else
  # Remove only our entry
  grep -v "^$CONFIG_PATH$" "$TRUSTED_FILE" > "$TRUSTED_FILE.tmp" 2>/dev/null || true
  mv "$TRUSTED_FILE.tmp" "$TRUSTED_FILE" 2>/dev/null || rm -f "$TRUSTED_FILE"
fi

# Check result
if echo "$menu" | grep -q "trusted-app"; then
  pass "trusted config correctly loaded"
else
  fail "trusted config was not loaded"
fi
