#!/usr/bin/env bats
#
# taskrunners.bats - Taskrunner integration tests
#
# These tests use the existing test directories with local .nunchuxrc files
#

load test_helper

# =============================================================================
# Just Taskrunner Tests
# =============================================================================

@test "taskrunner: just-test directory shows just tasks" {
    cd "$TEST_DIR/just-test"
    load_and_parse_config

    run build_combined_menu ""
    assert_output_contains "just hello"
    assert_output_contains "just build"
    assert_output_contains "just test"
    assert_output_contains "just clean"
}

@test "taskrunner: just-test shows only just (no npm or task)" {
    cd "$TEST_DIR/just-test"
    load_and_parse_config

    run build_combined_menu ""
    assert_output_not_contains "npm"
    assert_output_not_contains "task build"
}

@test "taskrunner: just section has divider" {
    cd "$TEST_DIR/just-test"
    load_and_parse_config

    run build_combined_menu ""
    # Should have a divider line with "just"
    [[ "$output" == *"───"*"just"* ]]
}

# =============================================================================
# npm Taskrunner Tests
# =============================================================================

@test "taskrunner: npm-test directory shows npm scripts" {
    cd "$TEST_DIR/npm-test"
    load_and_parse_config

    run build_combined_menu ""
    assert_output_contains "npm"
}

@test "taskrunner: npm-test shows only npm (no just or task)" {
    cd "$TEST_DIR/npm-test"
    load_and_parse_config

    run build_combined_menu ""
    assert_output_not_contains "just hello"
    assert_output_not_contains "task build"
}

# =============================================================================
# Task Taskrunner Tests
# =============================================================================

@test "taskrunner: task-test directory shows task tasks" {
    cd "$TEST_DIR/task-test"
    load_and_parse_config

    run build_combined_menu ""
    assert_output_contains "task"
}

@test "taskrunner: task-test shows only task (no just or npm)" {
    cd "$TEST_DIR/task-test"
    load_and_parse_config

    run build_combined_menu ""
    assert_output_not_contains "just hello"
    assert_output_not_contains "npm"
}

# =============================================================================
# All Plugins Test
# =============================================================================

@test "taskrunner: all-plugins shows all three taskrunners" {
    cd "$TEST_DIR/all-plugins"
    load_and_parse_config

    run build_combined_menu ""
    # Should have all three taskrunner dividers
    [[ "$output" == *"just"* ]]
    [[ "$output" == *"npm"* ]]
    [[ "$output" == *"task"* ]]
}

@test "taskrunner: all-plugins shows apps and taskrunners" {
    cd "$TEST_DIR/all-plugins"
    load_and_parse_config

    run build_combined_menu ""
    # Should have apps
    assert_output_contains "lazygit"
    assert_output_contains "htop"
    # And taskrunners
    assert_output_contains "just"
    assert_output_contains "npm"
}

@test "taskrunner: all-plugins shows submenu" {
    cd "$TEST_DIR/all-plugins"
    load_and_parse_config

    run build_combined_menu ""
    assert_output_contains "menu:system"
}

@test "taskrunner: all-plugins shows dirbrowser" {
    cd "$TEST_DIR/all-plugins"
    load_and_parse_config

    run build_combined_menu ""
    assert_output_contains "dirbrowser:config"
}

# =============================================================================
# Taskrunner Enable/Disable Tests
# =============================================================================

@test "taskrunner: disabled taskrunner not shown" {
    create_test_config "$TEMP_DIR/test" "[taskrunner:just]
enabled = false"

    # Create a justfile
    echo "hello:" > "$TEMP_DIR/test/justfile"

    cd "$TEMP_DIR/test"
    load_and_parse_config

    run build_combined_menu ""
    assert_output_not_contains "just"
}

@test "taskrunner: enabled taskrunner shown" {
    create_test_config "$TEMP_DIR/test" "[taskrunner:just]
enabled = true"

    # Create a justfile
    cat > "$TEMP_DIR/test/justfile" << 'EOF'
# Say hello
hello:
    echo hello
EOF

    cd "$TEMP_DIR/test"
    load_and_parse_config

    run build_combined_menu ""
    assert_output_contains "just"
}

# =============================================================================
# Taskrunner Icon Tests
# =============================================================================

@test "taskrunner: custom icon shown in divider" {
    create_test_config "$TEMP_DIR/test" "[taskrunner:just]
enabled = true
icon = TESTICON"

    # Create a justfile
    cat > "$TEMP_DIR/test/justfile" << 'EOF'
hello:
    echo hello
EOF

    cd "$TEMP_DIR/test"
    load_and_parse_config

    run build_combined_menu ""
    assert_output_contains "TESTICON"
}

# =============================================================================
# Taskrunner Status Icon Configuration Tests
# =============================================================================

@test "taskrunner: default status icons are emojis" {
    source "$NUNCHUX_ROOT/lib/config.sh"

    [[ "$TASKRUNNER_ICON_RUNNING" == "🔄" ]]
    [[ "$TASKRUNNER_ICON_SUCCESS" == "✅" ]]
    [[ "$TASKRUNNER_ICON_FAILED" == "❌" ]]
}

@test "taskrunner: [taskrunner] section configures icon_running" {
    create_test_config "$TEMP_DIR/test" "[taskrunner]
icon_running = RUNNING"

    cd "$TEMP_DIR/test"
    load_and_parse_config

    [[ "$TASKRUNNER_ICON_RUNNING" == "RUNNING" ]]
}

@test "taskrunner: [taskrunner] section configures icon_success" {
    create_test_config "$TEMP_DIR/test" "[taskrunner]
icon_success = SUCCESS"

    cd "$TEMP_DIR/test"
    load_and_parse_config

    [[ "$TASKRUNNER_ICON_SUCCESS" == "SUCCESS" ]]
}

@test "taskrunner: [taskrunner] section configures icon_failed" {
    create_test_config "$TEMP_DIR/test" "[taskrunner]
icon_failed = FAILED"

    cd "$TEMP_DIR/test"
    load_and_parse_config

    [[ "$TASKRUNNER_ICON_FAILED" == "FAILED" ]]
}

@test "taskrunner: [taskrunner] section configures all icons together" {
    create_test_config "$TEMP_DIR/test" "[taskrunner]
icon_running = R
icon_success = S
icon_failed = F"

    cd "$TEMP_DIR/test"
    load_and_parse_config

    [[ "$TASKRUNNER_ICON_RUNNING" == "R" ]]
    [[ "$TASKRUNNER_ICON_SUCCESS" == "S" ]]
    [[ "$TASKRUNNER_ICON_FAILED" == "F" ]]
}

@test "taskrunner: [taskrunner] section not detected as old format" {
    create_test_config "$TEMP_DIR/test" "[settings]
menu_width = 50%

[taskrunner]
icon_running = TEST

[app:myapp]
cmd = echo hello"

    cd "$TEMP_DIR/test"
    local config_file="$TEMP_DIR/test/.nunchuxrc"

    # Should NOT be detected as old format
    run is_old_config_format "$config_file"
    [[ "$status" -eq 1 ]]
}

# =============================================================================
# Taskrunner Kill Function Tests
# =============================================================================

@test "taskrunner: taskrunner_kill returns 1 for non-taskrunner name" {
    load_modules

    run taskrunner_kill "lazygit"
    [[ "$status" -eq 1 ]]
}

@test "taskrunner: taskrunner_kill returns 1 for app-style name" {
    load_modules

    run taskrunner_kill "myapp"
    [[ "$status" -eq 1 ]]
}
