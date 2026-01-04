# Nunchux Full Demo
# Run: vhs full-demo.tape
#
# Based on ~/dotfiles/nunchux/config
# Shows:
# - Basic menu navigation with status info
# - Keyboard shortcuts (Ctrl-G, Ctrl-C)
# - Submenus with live status
# - Directory browser
# - Taskrunners

Output full-demo.gif
Set Width 1600
Set Height 900
Set FontSize 16
Set FontFamily "CaskaydiaMono Nerd Font"
Set Theme "Catppuccin Mocha"
Set Padding 0

# Start in tmux
Hide
Type "tmux new-session -s 'nunchux demo' -c ~/source/nunchux/demos"
Enter
Sleep 1s
Show

# === PART 1: Open notes in popup ===

Sleep 500ms
Ctrl+Space
Sleep 1.5s

# Filter to notes
Type "notes"
Sleep 500ms

# Open in popup (default action)
Enter
Sleep 5s

# Close notes
Type ":q"
Enter
Sleep 500ms

# === PART 2: Open menu and show shortcuts ===

Ctrl+Space
Sleep 2s

# Type explanation
Type "filter items with fzf, or use your configured shortcuts (ctrl-/ to see them)"
Sleep 2s

# Clear the filter text
Ctrl+U
Sleep 500ms

# Toggle shortcut visibility
Ctrl+T
Sleep 1.5s

Type "git"

# Shortcuts are now visible (ctrl-g, ctrl-c, ctrl-n)
Sleep 1s

# === PART 3: Use a direct shortcut (ctrl-g for lazygit) ===

Ctrl+G
Sleep 2.5s

# Quit lazygit
Type "q"
Sleep 800ms

# === PART 4: System submenu with live status ===

Ctrl+Space
Sleep 1.5s

# The system submenu shows live stats (load, RAM, disk, wifi, battery)
Type "system"
Sleep 5000ms
Enter
Sleep 2s

# Open btop from system submenu
Type "btop"
Sleep 500ms
Enter
Sleep 3s

# Quit btop
Type "q"
Sleep 800ms

# === PART 5: Directory browser ===

# Use shortcut ctrl-c for config dirbrowser
Ctrl+Space
Sleep 1s
Ctrl+C
Sleep 2s

# Filter for config first
Type "config"
Sleep 800ms

# Then narrow down to nunchux
Ctrl+U
Type "nunchux"
Sleep 800ms
Enter
Sleep 2s

# Close editor
Type ":q"
Enter
Sleep 500ms

# === PART 6: Taskrunner with Tab (background) ===

# We're in demos/ which has a justfile - nunchux will detect it
Ctrl+Space
Sleep 2s

# Filter to hello task
Type "hello"
Sleep 500ms

# Run task with Enter (opens in window with focus)
Enter
Sleep 6s

# Task is done - wait for the done message
Sleep 3s

# Press key to close task window
Type " "
Sleep 500ms

# === PART 8: Files with yazi ===

Ctrl+Space
Sleep 1s
Type "files"
Sleep 500ms
Enter
Sleep 3s

# Browse around in yazi
Type "j"
Sleep 200ms
Type "j"
Sleep 200ms
Type "l"
Sleep 1s

# Quit yazi
Type "q"
Sleep 500ms

# === END: Demo action menu (Ctrl-J) with thanks ===

Ctrl+Space
Sleep 1s
Type "thanks"
Sleep 500ms

# Open action menu with Ctrl-J
Ctrl+J
Sleep 1.5s

# Select "Open in pane to the right"
Down
Sleep 150ms
Down
Sleep 150ms
Down
Sleep 150ms
Enter
Sleep 4s
