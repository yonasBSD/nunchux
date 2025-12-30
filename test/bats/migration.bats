#!/usr/bin/env bats
#
# migration.bats - Config migration tests
#

load test_helper

# =============================================================================
# Old Format Detection Tests
# =============================================================================

@test "migration: detects old format without type prefix" {
  create_test_config "$TEMP_DIR/test" "[settings]
menu_width = 60%

[lazygit]
cmd = lazygit"

  cd "$TEMP_DIR/test"
  load_modules

  run is_old_config_format "$TEMP_DIR/test/.nunchuxrc"
  [[ "$status" -eq 0 ]]
}

@test "migration: new format not detected as old" {
  create_test_config "$TEMP_DIR/test" "[settings]
menu_width = 60%

[app:lazygit]
cmd = lazygit"

  cd "$TEMP_DIR/test"
  load_modules

  run is_old_config_format "$TEMP_DIR/test/.nunchuxrc"
  [[ "$status" -ne 0 ]]
}

@test "migration: settings-only config not detected as old" {
  create_test_config "$TEMP_DIR/test" "[settings]
menu_width = 60%
menu_height = 50%"

  cd "$TEMP_DIR/test"
  load_modules

  run is_old_config_format "$TEMP_DIR/test/.nunchuxrc"
  [[ "$status" -ne 0 ]]
}

# =============================================================================
# Config Conversion Tests
# =============================================================================

@test "migration: converts app section to [app:name]" {
  create_test_config "$TEMP_DIR/test" "[lazygit]
cmd = lazygit"

  cd "$TEMP_DIR/test"
  load_modules

  run convert_config "$TEMP_DIR/test/.nunchuxrc"
  assert_output_contains "[app:lazygit]"
}

@test "migration: converts directory browser to [dirbrowser:name]" {
  create_test_config "$TEMP_DIR/test" "[configs]
directory = ~/.config"

  cd "$TEMP_DIR/test"
  load_modules

  run convert_config "$TEMP_DIR/test/.nunchuxrc"
  assert_output_contains "[dirbrowser:configs]"
}

@test "migration: preserves settings section" {
  create_test_config "$TEMP_DIR/test" "[settings]
menu_width = 60%
menu_height = 50%

[lazygit]
cmd = lazygit"

  cd "$TEMP_DIR/test"
  load_modules

  run convert_config "$TEMP_DIR/test/.nunchuxrc"
  assert_output_contains "[settings]"
  assert_output_contains "menu_width = 60%"
}

@test "migration: adds order property to sections" {
  create_test_config "$TEMP_DIR/test" "[first]
cmd = echo first

[second]
cmd = echo second"

  cd "$TEMP_DIR/test"
  load_modules

  run convert_config "$TEMP_DIR/test/.nunchuxrc"
  assert_output_contains "order = 10"
  assert_output_contains "order = 20"
}

@test "migration: detects submenu from slash in name" {
  create_test_config "$TEMP_DIR/test" "[system]

[system/htop]
cmd = htop"

  cd "$TEMP_DIR/test"
  load_modules

  run convert_config "$TEMP_DIR/test/.nunchuxrc"
  assert_output_contains "[menu:system]"
  assert_output_contains "[app:system/htop]"
}

@test "migration: converts plugin settings to taskrunner sections" {
  create_test_config "$TEMP_DIR/test" "[settings]
plugin_enabled_just = true
plugin_icon_just = X"

  cd "$TEMP_DIR/test"
  load_modules

  run convert_config "$TEMP_DIR/test/.nunchuxrc"
  assert_output_contains "[taskrunner:just]"
  assert_output_contains "enabled = true"
  assert_output_contains "icon = X"
}

# =============================================================================
# Full Migration Flow Tests
# =============================================================================

@test "migration: old config produces valid new config" {
  create_test_config "$TEMP_DIR/test" "[settings]
menu_width = 60%

[lazygit]
cmd = lazygit
desc = Git TUI

[configs]
directory = ~/.config

[system]

[system/htop]
cmd = htop"

  cd "$TEMP_DIR/test"
  load_modules

  # Convert the config
  convert_config "$TEMP_DIR/test/.nunchuxrc" >"$TEMP_DIR/test/new.nunchuxrc"

  # Parse the new config - should not error
  run parse_config "$TEMP_DIR/test/new.nunchuxrc"
  [[ "$status" -eq 0 ]]
}

@test "migration: vim modeline excluded from convert_config output" {
  create_test_config "$TEMP_DIR/test" "[settings]
menu_width = 60%

[myapp]
cmd = myapp

# vim: ft=dosini"

  cd "$TEMP_DIR/test"
  load_modules

  # Filter out modeline like the migration does, then convert
  grep -v "^#.*vim:" "$TEMP_DIR/test/.nunchuxrc" >"$TEMP_DIR/test/.nunchuxrc.filtered"
  run convert_config "$TEMP_DIR/test/.nunchuxrc.filtered"

  [[ "$status" -eq 0 ]]
  assert_output_contains "[app:myapp]"
  assert_output_contains "[settings]"
  # Modeline should not be in output
  [[ "$output" != *"vim:"* ]]
}

# vim: ft=bash ts=2 sw=2 et
