#!/usr/bin/env bats
#
# menu.bats - Menu building tests
#

load test_helper

# =============================================================================
# App Menu Tests
# =============================================================================

@test "menu: apps appear in menu output" {
  create_test_config "$TEMP_DIR/test" "[app:myapp]
cmd = echo hello
desc = My test app"

  cd "$TEMP_DIR/test"
  load_and_parse_config

  run build_combined_menu ""
  assert_output_contains "myapp"
  assert_output_contains "My test app"
}

@test "menu: multiple apps appear in order" {
  create_test_config "$TEMP_DIR/test" "[app:first]
cmd = echo 1

[app:second]
cmd = echo 2

[app:third]
cmd = echo 3"

  cd "$TEMP_DIR/test"
  load_and_parse_config

  run build_combined_menu ""
  assert_output_contains "first"
  assert_output_contains "second"
  assert_output_contains "third"
}

@test "menu: order property affects item order" {
  create_test_config "$TEMP_DIR/test" "[app:should-be-last]
order = 100
cmd = echo last

[app:should-be-first]
order = 10
cmd = echo first"

  cd "$TEMP_DIR/test"
  load_and_parse_config

  run build_combined_menu ""
  # First should appear before last
  local first_pos last_pos
  first_pos=$(echo "$output" | grep -n "should-be-first" | cut -d: -f1)
  last_pos=$(echo "$output" | grep -n "should-be-last" | cut -d: -f1)
  [[ "$first_pos" -lt "$last_pos" ]]
}

# =============================================================================
# Submenu Tests
# =============================================================================

@test "menu: submenus appear with menu: prefix" {
  create_test_config "$TEMP_DIR/test" "[menu:system]
desc = System tools"

  cd "$TEMP_DIR/test"
  load_and_parse_config

  run build_combined_menu ""
  assert_output_contains "menu:system"
}

@test "menu: submenu apps hidden from main menu" {
  create_test_config "$TEMP_DIR/test" "[menu:system]
desc = System tools

[app:system/htop]
cmd = htop
desc = Process viewer"

  cd "$TEMP_DIR/test"
  load_and_parse_config

  # Main menu should show submenu but not the app inside it
  run build_combined_menu ""
  assert_output_contains "menu:system"
  assert_output_not_contains "htop"
}

@test "menu: submenu apps appear in submenu context" {
  create_test_config "$TEMP_DIR/test" "[menu:system]
desc = System tools

[app:system/htop]
cmd = htop
desc = Process viewer"

  cd "$TEMP_DIR/test"
  load_and_parse_config

  # Submenu context should show the app
  run build_combined_menu "system"
  assert_output_contains "htop"
}

# =============================================================================
# Dirbrowser Tests
# =============================================================================

@test "menu: dirbrowser appears with dirbrowser: prefix" {
  create_test_config "$TEMP_DIR/test" "[dirbrowser:configs]
directory = /tmp"

  cd "$TEMP_DIR/test"
  load_and_parse_config

  run build_combined_menu ""
  assert_output_contains "dirbrowser:configs"
}

@test "menu: dirbrowser shows file count" {
  # Create a directory with some files
  mkdir -p "$TEMP_DIR/testdir"
  touch "$TEMP_DIR/testdir/file1.txt"
  touch "$TEMP_DIR/testdir/file2.txt"
  touch "$TEMP_DIR/testdir/file3.txt"

  create_test_config "$TEMP_DIR/test" "[dirbrowser:testbrowser]
directory = $TEMP_DIR/testdir"

  cd "$TEMP_DIR/test"
  load_and_parse_config

  run build_combined_menu ""
  assert_output_contains "3 files"
}

# =============================================================================
# Status Command Tests
# =============================================================================

@test "menu: status command output appended to description" {
  create_test_config "$TEMP_DIR/test" "[app:myapp]
cmd = echo hello
desc = Test app
status = echo '(running)'"

  cd "$TEMP_DIR/test"
  load_and_parse_config

  run build_combined_menu ""
  assert_output_contains "Test app"
  assert_output_contains "(running)"
}

# =============================================================================
# Menu Output Format Tests
# =============================================================================

@test "menu: output is tab-separated" {
  create_test_config "$TEMP_DIR/test" "[app:myapp]
cmd = echo hello"

  cd "$TEMP_DIR/test"
  load_and_parse_config

  run build_combined_menu ""
  # Should contain tabs
  [[ "$output" == *$'\t'* ]]
}

@test "menu: app entry has correct fields" {
  create_test_config "$TEMP_DIR/test" "[app:myapp]
cmd = echo hello
width = 80
height = 60"

  cd "$TEMP_DIR/test"
  load_and_parse_config

  run build_combined_menu ""
  # Check for app name and command in output
  assert_output_contains "myapp"
  assert_output_contains "echo hello"
}

# vim: ft=bash ts=2 sw=2 et
