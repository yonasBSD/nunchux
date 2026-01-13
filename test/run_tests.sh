#!/usr/bin/env bash
#
# test/run_tests.sh - Simple test runner for nunchux
#
# Usage:
#   ./run_tests.sh           # Run all tests
#   ./run_tests.sh -i        # Interactive mode (fzf menu)
#   ./run_tests.sh <name>    # Run specific test folder
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NUNCHUX_BIN="$PROJECT_ROOT/bin/nunchux"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Counters
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

# ============================================================================
# Test discovery and execution
# ============================================================================

# Find all test folders (those containing test.sh)
discover_tests() {
  for dir in "$SCRIPT_DIR"/*/; do
    [[ -f "$dir/test.sh" ]] && basename "$dir"
  done
}

# Check if a test is visual (requires user interaction)
is_visual_test() {
  local name="$1"
  local test_script="$SCRIPT_DIR/$name/test.sh"
  grep -q "run_nunchux_popup" "$test_script" 2>/dev/null
}

# Run a single test by folder name
run_test() {
  local name="$1"
  local test_dir="$SCRIPT_DIR/$name"
  local test_script="$test_dir/test.sh"

  if [[ ! -f "$test_script" ]]; then
    echo -e "${YELLOW}[SKIP]${RESET} $name: no test.sh found"
    ((SKIP_COUNT++)) || true
    return 0
  fi

  # Run the test script from its directory (needed for taskrunner tests)
  if (cd "$test_dir" && bash "$test_script"); then
    ((PASS_COUNT++)) || true
  else
    ((FAIL_COUNT++)) || true
  fi
}

# Run all discovered tests
run_all() {
  echo ""
  echo -e "${CYAN}Running tests...${RESET}"
  echo ""

  local prev_was_visual=false
  while IFS= read -r test_name; do
    # Only prompt before visual tests (or after a visual test)
    if is_visual_test "$test_name"; then
      echo ""
      read -rp "Press Enter for next test ($test_name)... " </dev/tty
      echo ""
      prev_was_visual=true
    elif [[ "$prev_was_visual" == true ]]; then
      echo ""
      prev_was_visual=false
    fi
    run_test "$test_name"
  done < <(discover_tests | sort)

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  local total=$((PASS_COUNT + FAIL_COUNT + SKIP_COUNT))
  echo -e "${BOLD}$total tests:${RESET} ${GREEN}$PASS_COUNT passed${RESET}, ${RED}$FAIL_COUNT failed${RESET}, ${YELLOW}$SKIP_COUNT skipped${RESET}"
  echo ""

  [[ $FAIL_COUNT -gt 0 ]] && return 1
  return 0
}

# Run a specific test by name
run_one() {
  local name="$1"
  local test_dir="$SCRIPT_DIR/$name"

  if [[ ! -d "$test_dir" ]]; then
    echo "Unknown test: $name" >&2
    echo "Available tests:" >&2
    discover_tests | sed 's/^/  /' >&2
    return 1
  fi

  echo ""
  echo -e "${CYAN}Running test: $name${RESET}"
  echo ""
  run_test "$name"
  echo ""

  [[ $FAIL_COUNT -gt 0 ]] && return 1
  return 0
}

# Interactive mode with fzf
run_interactive() {
  local tests
  tests=$(discover_tests | sort)

  # Add visual test options (for tests that need human verification)
  local options="$tests"
  options+=$'\n'"visual: integration"
  options+=$'\n'"visual: app-actions"
  options+=$'\n'"visual: submenu"

  local selection
  selection=$(echo "$options" | fzf --prompt="Select test > " --height=40%) || return 0

  [[ -z "$selection" ]] && return 0

  if [[ "$selection" == visual:* ]]; then
    local folder="${selection#visual: }"
    local dir="$SCRIPT_DIR/$folder"
    local config_file="$dir/.nunchuxrc"
    [[ -f "$dir/config" ]] && config_file="$dir/config"

    echo ""
    echo -e "${CYAN}Launching nunchux in $folder...${RESET}"
    echo -e "${CYAN}Press Esc to exit, then mark pass/fail${RESET}"
    echo ""

    (cd "$dir" && NUNCHUX_RC_FILE="$config_file" "$NUNCHUX_BIN") || true

    echo ""
    read -rp "Did the test pass? [y/n/s] " answer
    case "$answer" in
      y|Y) echo -e "${GREEN}[PASS]${RESET} $folder: visual inspection passed" ;;
      n|N) echo -e "${RED}[FAIL]${RESET} $folder: visual inspection failed" ;;
      *) echo -e "${YELLOW}[SKIP]${RESET} $folder: skipped" ;;
    esac
  else
    run_one "$selection"
  fi
}

# ============================================================================
# Main
# ============================================================================

usage() {
  cat <<EOF
Usage: $(basename "$0") [options] [test-name]

Options:
  -i, --interactive    Interactive mode (fzf menu)
  -l, --list           List available tests
  -h, --help           Show this help

Examples:
  $(basename "$0")              Run all tests
  $(basename "$0") basic-apps   Run just the basic-apps test
  $(basename "$0") -i           Pick test interactively
EOF
}

main() {
  case "${1:-}" in
    -i|--interactive)
      run_interactive
      ;;
    -l|--list)
      discover_tests | sort
      ;;
    -h|--help)
      usage
      ;;
    "")
      run_all
      ;;
    *)
      run_one "$1"
      ;;
  esac
}

main "$@"
