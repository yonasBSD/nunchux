#!/usr/bin/env bats
#
# config.bats - Config discovery and parsing tests
#

load test_helper

# =============================================================================
# Config Discovery Tests
# =============================================================================

@test "config: finds .nunchuxrc in current directory" {
  cd "$TEST_DIR/just-test"
  run get_config_file
  [[ "$output" == *"just-test/.nunchuxrc" ]]
}

@test "config: finds .nunchuxrc in all-plugins directory" {
  cd "$TEST_DIR/all-plugins"
  run get_config_file
  [[ "$output" == *"all-plugins/.nunchuxrc" ]]
}

@test "config: searches upward for .nunchuxrc" {
  # Create nested directory structure
  mkdir -p "$TEMP_DIR/parent/child/grandchild"
  echo "[settings]" >"$TEMP_DIR/parent/.nunchuxrc"

  cd "$TEMP_DIR/parent/child/grandchild"
  run get_config_file
  [[ "$output" == *"parent/.nunchuxrc" ]]
}

@test "config: finds .nunchuxrc in intermediate parent" {
  # Create structure where config is in middle
  mkdir -p "$TEMP_DIR/a/b/c/d"
  echo "[settings]" >"$TEMP_DIR/a/b/.nunchuxrc"

  cd "$TEMP_DIR/a/b/c/d"
  run get_config_file
  [[ "$output" == *"a/b/.nunchuxrc" ]]
}

@test "config: NUNCHUX_RC_FILE env overrides local search" {
  # Create a local config that should be ignored
  mkdir -p "$TEMP_DIR/local"
  echo "[settings]" >"$TEMP_DIR/local/.nunchuxrc"

  # Create an override config
  echo "[settings]" >"$TEMP_DIR/override.nunchuxrc"

  cd "$TEMP_DIR/local"
  NUNCHUX_RC_FILE_EXPLICIT=1
  NUNCHUX_RC_FILE="$TEMP_DIR/override.nunchuxrc"

  run get_config_file
  [[ "$output" == *"override.nunchuxrc" ]]
}

@test "config: returns empty when no config found" {
  mkdir -p "$TEMP_DIR/empty"
  cd "$TEMP_DIR/empty"

  # Override to prevent finding user's real config
  NUNCHUX_RC_FILE="$TEMP_DIR/nonexistent"

  run get_config_file
  [[ -z "$output" ]]
}

# =============================================================================
# Config Parsing Tests
# =============================================================================

@test "config: parses [settings] section" {
  create_test_config "$TEMP_DIR/test" "[settings]
menu_width = 80%
menu_height = 60%"

  cd "$TEMP_DIR/test"
  load_modules
  parse_config "$(get_config_file)"

  [[ "$MENU_WIDTH" == "80%" ]]
  [[ "$MENU_HEIGHT" == "60%" ]]
}

@test "config: parses [app:name] section" {
  create_test_config "$TEMP_DIR/test" "[app:myapp]
cmd = echo hello
desc = Test app"

  cd "$TEMP_DIR/test"
  load_modules
  parse_config "$(get_config_file)"

  [[ "${APP_CMD[myapp]}" == "echo hello" ]]
  [[ "${APP_DESC[myapp]}" == "Test app" ]]
}

@test "config: parses [menu:name] section" {
  create_test_config "$TEMP_DIR/test" "[menu:system]
desc = System tools"

  cd "$TEMP_DIR/test"
  load_modules
  parse_config "$(get_config_file)"

  [[ "${MENU_DESC[system]}" == "System tools" ]]
}

@test "config: parses [dirbrowser:name] section" {
  create_test_config "$TEMP_DIR/test" "[dirbrowser:configs]
directory = /tmp
depth = 2"

  cd "$TEMP_DIR/test"
  load_modules
  parse_config "$(get_config_file)"

  [[ "${DIRBROWSE_DIR[configs]}" == "/tmp" ]]
  [[ "${DIRBROWSE_DEPTH[configs]}" == "2" ]]
}

@test "config: parses [taskrunner:name] section" {
  create_test_config "$TEMP_DIR/test" "[taskrunner:just]
enabled = true
icon = X"

  cd "$TEMP_DIR/test"
  load_modules
  parse_config "$(get_config_file)"

  [[ "${TASKRUNNER_ENABLED[just]}" == "true" ]]
  [[ "${TASKRUNNER_ICON[just]}" == "X" ]]
}

@test "config: handles line continuation with backslash" {
  create_test_config "$TEMP_DIR/test" "[app:multiline]
cmd = echo first && \\
      echo second"

  cd "$TEMP_DIR/test"
  load_modules
  parse_config "$(get_config_file)"

  [[ "${APP_CMD[multiline]}" == *"first"* ]]
  [[ "${APP_CMD[multiline]}" == *"second"* ]]
}

@test "config: ignores comments" {
  create_test_config "$TEMP_DIR/test" "# This is a comment
[settings]
# Another comment
menu_width = 70%"

  cd "$TEMP_DIR/test"
  load_modules
  parse_config "$(get_config_file)"

  [[ "$MENU_WIDTH" == "70%" ]]
}

# =============================================================================
# has_config_file Tests
# =============================================================================

@test "config: has_config_file returns true when .nunchuxrc exists" {
  cd "$TEST_DIR/just-test"
  run has_config_file
  [[ "$status" -eq 0 ]]
}

@test "config: has_config_file returns false when no config" {
  mkdir -p "$TEMP_DIR/empty"
  cd "$TEMP_DIR/empty"
  NUNCHUX_RC_FILE="$TEMP_DIR/nonexistent"

  run has_config_file
  [[ "$status" -ne 0 ]]
}

# vim: ft=bash ts=2 sw=2 et
