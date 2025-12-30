#!/usr/bin/env bash
#
# run_tests.sh - Run all BATS tests for nunchux
#
# Usage:
#   ./test/run_tests.sh           # Run all tests
#   ./test/run_tests.sh config    # Run only config tests
#   ./test/run_tests.sh -v        # Verbose output
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATS_DIR="$SCRIPT_DIR/bats"

# Find bats command
if ! command -v bats &>/dev/null; then
    echo "Error: bats is not installed."
    echo ""
    echo "Install with:"
    echo "  pacman -S bats          # Arch"
    echo "  brew install bats-core  # macOS"
    echo "  apt install bats        # Debian/Ubuntu"
    exit 1
fi

# Parse arguments
VERBOSE=""
FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE="--verbose-run"
            shift
            ;;
        -t|--tap)
            VERBOSE="--tap"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options] [test-name]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose    Show verbose output"
            echo "  -t, --tap        TAP output format"
            echo "  -h, --help       Show this help"
            echo ""
            echo "Test names:"
            echo "  config           Run config tests only"
            echo "  menu             Run menu tests only"
            echo "  taskrunners      Run taskrunner tests only"
            echo "  migration        Run migration tests only"
            echo ""
            echo "Examples:"
            echo "  $0               Run all tests"
            echo "  $0 config        Run config tests"
            echo "  $0 -v            Run all tests verbosely"
            exit 0
            ;;
        *)
            FILTER="$1"
            shift
            ;;
    esac
done

# Build test file list
if [[ -n "$FILTER" ]]; then
    TEST_FILES="$BATS_DIR/${FILTER}.bats"
    if [[ ! -f "$TEST_FILES" ]]; then
        echo "Error: Test file not found: $TEST_FILES"
        exit 1
    fi
else
    TEST_FILES="$BATS_DIR"/*.bats
fi

# Run tests
echo "Running nunchux tests..."
echo ""

# shellcheck disable=SC2086
bats $VERBOSE $TEST_FILES

# vim: ft=bash ts=2 sw=2 et
