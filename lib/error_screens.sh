#!/usr/bin/env bash
#
# lib/error_screens.sh - Error screens for nunchux
#
# All error display functions are centralized here for consistency.

# Guard against double-sourcing
[[ -n "${NUNCHUX_LIB_ERROR_SCREENS_LOADED:-}" ]] && return
NUNCHUX_LIB_ERROR_SCREENS_LOADED=1

# Show dependency error screen
# Usage: show_setup_error "dependency" FAILURES_ARRAY
show_setup_error() {
  local error_type="$1"
  local -n _details=$2

  [[ "$error_type" != "dependency" ]] && return

  echo ""
  echo -e "\033[1;31mMissing Dependencies\033[0m"
  echo ""
  for dep in "${!_details[@]}"; do
    echo "  - ${_details[$dep]}"
  done
  echo ""
  echo "Install the missing dependencies and try again."
  echo ""
  echo "Press any key to exit..."
  read -rsn1
  exit 1
}

# Show invalid keybinding error in a properly sized popup
# Usage: show_invalid_key_error "key-name"
show_invalid_key_error() {
  local invalid_key="$1"

  local script="/tmp/nunchux-err-$$"
  cat > "$script" <<NUNCHUX_ERR_EOF
#!/usr/bin/env bash
echo ""
echo -e "\033[1;33m  Chuck Norris's keyboard doesn't have a Ctrl key.\033[0m"
echo -e "\033[1;33m  He's always in control.\033[0m"
echo -e "\033[90m  but your keyboard needs valid bindings...\033[0m"
echo ""
echo -e "\033[1;31m  Unsupported key: $invalid_key\033[0m"
echo ""
echo "  Keys like shift-enter and ctrl-enter are not"
echo "  supported by terminals."
echo ""
echo "  Good alternatives: alt-enter, ctrl-s, tab, ctrl-o"
echo ""
echo -e "\033[90m  See: https://man.archlinux.org/man/fzf.1.en\033[0m"
echo ""
echo -e "\033[90m  Press any key...\033[0m"
read -n 1 -s
rm -f "$script"
NUNCHUX_ERR_EOF
  chmod +x "$script"

  tmux run-shell -b "sleep 0.05; tmux display-popup -E -w 58 -h 18 -T ' Invalid Keybinding ' '$script' || true"
  exit 0
}

# Show invalid shortcut error in a properly sized popup
# Usage: show_invalid_shortcut_error "error1\nerror2\n..."
show_invalid_shortcut_error() {
  local errors="$1"

  # Count error lines
  local err_count=0
  while IFS= read -r err; do
    [[ -n "$err" ]] && ((err_count++)) || true
  done <<<"$errors"

  # Popup dimensions: width 68, height = 14 + errors
  local popup_w=68
  local popup_h=$((14 + err_count))

  # Build reserved keys string
  local reserved="enter, esc, ctrl-x, /, $PRIMARY_KEY, $SECONDARY_KEY, $ACTION_MENU_KEY"

  # Create temp script for popup content
  local script="/tmp/nunchux-err-$$"
  cat > "$script" <<NUNCHUX_ERR_EOF
#!/usr/bin/env bash
echo ""
echo -e "\033[1;33m  Chuck Norris can trigger any shortcut with just a stare.\033[0m"
echo -e "\033[90m  but you need valid keybindings...\033[0m"
echo ""
echo -e "\033[1;31m  Invalid shortcuts:\033[0m"
$(while IFS= read -r err; do [[ -n "$err" ]] && echo "echo \"    $err\""; done <<<"$errors")
echo ""
echo "  Reserved: $reserved"
echo ""
echo -e "\033[90m  Press any key...\033[0m"
read -n 1 -s
rm -f "$script"
NUNCHUX_ERR_EOF
  chmod +x "$script"

  tmux run-shell -b "sleep 0.05; tmux display-popup -E -w $popup_w -h $popup_h -T ' Invalid Shortcuts ' '$script' || true"
  exit 0
}

# vim: ft=bash ts=2 sw=2 et
