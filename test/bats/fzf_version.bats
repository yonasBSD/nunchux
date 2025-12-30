#!/usr/bin/env bats
#
# fzf_version.bats - fzf version requirement tests
#

load test_helper

# =============================================================================
# fzf Version Check Tests
# =============================================================================

@test "fzf: check_fzf_version succeeds with current fzf" {
  # Clear any cached result
  rm -f /tmp/nunchux-fzf-version-ok

  run check_fzf_version
  [[ "$status" -eq 0 ]]
}

@test "fzf: version check caches result" {
  # Clear cache
  rm -f /tmp/nunchux-fzf-version-ok

  # First call should create cache
  check_fzf_version
  [[ -f /tmp/nunchux-fzf-version-ok ]]
}

@test "fzf: cached check is fast (uses mtime)" {
  # Ensure cache exists
  check_fzf_version

  # Second call should use cache (just verify it succeeds)
  run check_fzf_version
  [[ "$status" -eq 0 ]]
}

@test "fzf: FZF_MIN_VERSION is set to 0.66" {
  [[ "$FZF_MIN_VERSION" == "0.66" ]]
}

@test "fzf: current fzf version is 0.66+" {
  local version major minor
  version=$(fzf --version 2>/dev/null | head -1 | grep -oE '^[0-9]+\.[0-9]+' || echo "0.0")
  major="${version%%.*}"
  minor="${version#*.}"
  minor="${minor%%.*}"

  # Should be >= 0.66
  [[ "$major" -gt 0 ]] || [[ "$major" -eq 0 && "$minor" -ge 66 ]]
}

@test "fzf: check_fzf_version fails with old fzf (mocked)" {
  # Clear cache
  rm -f /tmp/nunchux-fzf-version-ok

  # Create a mock fzf that returns old version
  local mock_dir="$BATS_TMPDIR/mock-fzf-$$"
  mkdir -p "$mock_dir"
  cat >"$mock_dir/fzf" <<'EOF'
#!/bin/bash
echo "0.30.0 (brew)"
EOF
  chmod +x "$mock_dir/fzf"

  # Run with mock fzf first in PATH
  export PATH="$mock_dir:$PATH"
  run check_fzf_version

  # Should fail
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"too old"* ]]

  # Should NOT cache failed result
  [[ ! -f /tmp/nunchux-fzf-version-ok ]]

  # Cleanup
  rm -rf "$mock_dir"
}

# vim: ft=bash ts=2 sw=2 et
