# Changelog

All notable changes to nunchux will be documented in this file.

## [2.3.0]

### Working Directory in Menu Label

The menu now displays the current working directory in the border label, giving context for where commands will run:

```
nunchux (~/projects/myapp)
```

Submenus show both the submenu name and directory:

```
nunchux: system (~/projects/myapp)
```

This is enabled by default. To disable:

```ini
[settings]
show_cwd = false
```

### Direct Action Shortcuts

New keyboard shortcuts to open items in a specific mode, bypassing primary/secondary action settings:

| Setting | Suggested Key | Action |
|---------|---------------|--------|
| `popup_key` | `ctrl-p` | Open in popup |
| `window_key` | `ctrl-w` | Open in window |
| `background_window_key` | `ctrl-b` | Open in background window |
| `pane_horizontal_key` | `ctrl-h` | Open in horizontal split pane |
| `pane_vertical_key` | `ctrl-v` | Open in vertical split pane |

These are disabled by default. Configure only the ones you need:

```ini
[settings]
# Just enable horizontal/vertical pane shortcuts
pane_horizontal_key = ctrl-h
pane_vertical_key = ctrl-v
```

Or enable all action shortcuts:

```ini
[settings]
popup_key = ctrl-p
window_key = ctrl-w
background_window_key = ctrl-b
pane_horizontal_key = ctrl-h
pane_vertical_key = ctrl-v
```

Works on apps, taskrunners, and dirbrowser files. Configured shortcuts appear in the help header (toggle with `Ctrl-/`):

```
Enter: popup | Ctrl-O: window | Ctrl-X: kill | Ctrl-H: hsplit | Ctrl-V: vsplit
```

Note: These keys are reserved and cannot be used as item shortcuts.

### Action Menu

Press `ctrl-j` to open an action selection menu for the currently highlighted item. Choose how to open it:

- Open in popup
- Open in window
- Open in background window
- Open in horizontal split
- Open in vertical split

This provides quick access to all launch modes without needing to configure dedicated shortcuts for each action.

The key is configurable:

```ini
[settings]
action_menu_key = ctrl-j  # default
```

Set to empty to disable:

```ini
[settings]
action_menu_key =
```

Note: `ctrl-m` cannot be used as it's equivalent to Enter in terminals.

## [2.2.1]

### Fixed menu sorting when no `[order]` section is defined

- Items now sort alphabetically (apps, menus, dirbrowsers first, then taskrunners)
- Taskrunner items stay grouped by runner instead of being interleaved by task name
- Taskrunner dividers now appear directly before their items, not grouped at the top

## [2.2.0]

### Keyboard Shortcuts

Assign keyboard shortcuts to launch items directly from the menu:

```ini
[app:lazygit]
cmd = lazygit
shortcut = ctrl-g

[menu:system]
shortcut = ctrl-s

[dirbrowser:configs]
directory = ~/.config
shortcut = ctrl-c
```

Press the shortcut key while the menu is open to launch the item immediately.

- **Toggle visibility** - Press `Ctrl-/` to show/hide the shortcut column
- **Validation** - Invalid, reserved, or duplicate shortcuts show an error screen at startup
- **Reserved keys** - `enter`, `esc`, `ctrl-x`, `/`, and your configured primary/secondary keys cannot be used

Shortcuts are available on apps, submenus, and directory browsers. Taskrunner items cannot have shortcuts (they're discovered at runtime).

### Maximum Dimensions

Cap popup and menu sizes on large screens with new `max_*` settings:

```ini
[settings]
popup_width = 90%
popup_height = 90%
max_popup_height = 50
max_popup_width = 160

menu_width = 60%
menu_height = 50%
max_menu_width = 120
max_menu_height = 40
```

Percentages are calculated against the tmux window size, then clamped to the maximum.

### Declarative Ordering

The per-item `order` property has been replaced with declarative `[order]` sections for simpler configuration:

```ini
[order]
lazygit
config
taskrunner:just
system
taskrunner:npm
docker
```

Items are displayed in the order listed. Unlisted items are appended alphabetically.

- **Taskrunners in main order** - Use `taskrunner:name` format to position taskrunners anywhere in the menu
- **Submenu ordering** - Use `[order:submenu_name]` to control item order within submenus
- **Migration assistant** - Automatically converts old `order =` properties to new format with backup

When you launch nunchux with the old `order =` properties, an interactive migration prompt will convert your config automatically.

### Bug Fixes

- Fixed helper commands (`ago`, `lines`, `nearest`) not working in status commands when environment inheritance was enabled

## [2.1.0]

### New Features

#### Environment Variable Inheritance

Apps launched via nunchux now inherit the parent shell's environment (PATH, nvm, pyenv, custom exports, etc.). This works even when invoking nunchux from within vim, lazygit, or other apps.

To enable, add to your shell rc:

```bash
source ~/.tmux/plugins/nunchux/shell-init.bash  # or .zsh/.fish
```

#### Configurable Actions

Control how items open with `primary_action` and `secondary_action`:

- `popup` - Open in tmux popup
- `window` - Open in window with focus
- `background_window` - Open in window, stay in current pane

Configure globally or per-item:

```ini
[settings]
primary_action = popup
secondary_action = window

[app:lazygit]
primary_action = window  # Override for this app

[taskrunner:npm]
primary_action = background_window  # Run npm tasks in background
```

Default actions by type:

- Apps: popup / window
- Taskrunners: window / background_window
- Dirbrowsers: popup / window

#### Task Runner Improvements

- Tasks now run in dedicated windows with live status updates
- Primary key (Enter): Run task and switch focus to its window
- Secondary key (Ctrl-O): Run task in background, stay in current pane
- Configurable status icons for running, success, and failed states
- Kill running taskrunner windows with Ctrl-X
- Window reuse - running the same task twice reuses the existing window
- Better window titles showing task name and status
- Tasks can now run in popups (configure `primary_action = popup`)

```ini
[taskrunner]
icon_running = ●
icon_success = ✓
icon_failed = ✗
```

#### Configurable Keybindings

- New `primary_key` and `secondary_key` settings (default: enter, ctrl-o)
- Key validation with helpful error messages for unsupported keys

```ini
[settings]
primary_key = enter
secondary_key = ctrl-o
```

#### Customizable Label

New `label` setting controls the title shown in borders and popups:

```ini
[settings]
label = nunchux
```

The label appears consistently across all UI elements:

- Main menu border: `nunchux`
- Submenus: `nunchux: system`
- Apps: `nunchux: lazygit`
- Submenu apps: `nunchux: system | btop`
- Dirbrowsers: `nunchux: config`
- Dirbrowser files: `nunchux: config | folder/file.txt`

### Improvements

- Centralized launch logic in `nunchux-run` for consistent behavior
- Consistent title formatting across all popups and menus
- Border labels now left-aligned
- Better fzf error handling
- Vim modelines added to all source files
- New integration tests for environment inheritance

## [2.0.0]

Major update with a new modular architecture and config format with automatic migration.

### Breaking Changes

**New config format** - Sections now require type prefixes:

```ini
[lazygit]      →    [app:lazygit]
[system]       →    [menu:system]
[configs]      →    [dirbrowser:configs]
```

**Task runners require opt-in** - No longer enabled by default:

```ini
[taskrunner:just]
enabled = true
```

**fzf 0.45+ required** - For faster menu updates via unix sockets

### Migration

When you launch nunchux with an old config, you'll see an interactive migration prompt:

- Converts your config to the new format automatically
- Lets you choose which task runners to enable
- Saves a backup of your original config

### New Features

- **Per-project configs** - Place `.nunchuxrc` in any directory, searches upward like `.gitignore`
- **Ordering control** - ~~New `order` property on any item~~ (replaced by `[order]` sections in v2.3.0)

### Improvements

- Modular codebase (lib/, modules/, taskrunners/)
- Comprehensive test suite (BATS)
- Improved caching and performance

### Upgrading

```
prefix + U  # TPM will handle the upgrade for you
```

The migration prompt will guide you through the config update.

## [1.0.0]

The first official release of nunchux - a command palette for your tmux life.

### Features

#### Apps & Popups

- Launch TUI apps in tmux popups (Enter) or windows (Ctrl-O)
- Automatic switch-to if app is already running - no duplicates
- Kill running apps with Ctrl-X
- Dynamic status info (git changes, docker containers, load, etc.)

#### Submenus

- Organize apps into collapsible submenus
- Each submenu can have its own status command

#### Directory Browsers

- Browse and open files from configured directories
- Multiple sort modes: by modification time, grouped by folder, or alphabetical
- Configurable depth, glob filters, and caching

#### Task Runners

- Built-in support for just, npm, and task (Taskfile)
- Auto-detect project files and show available tasks
- Tasks run in your current pane

#### Per-Project Configs

- Place .nunchuxrc in any directory
- Nunchux searches upward (like .gitignore)
- Great for project-specific apps and tasks

#### Performance

- Menu caching with instant display
- Background refresh with fzf hot-swap
- Feels snappy even with complex status commands

#### Helper Functions

- `ago <file>` - relative modification time
- `lines <file>` - line count
- `nearest <file>` - find file by walking up directory tree

### Requirements

- tmux
- fzf v0.45+
- curl

### Install

```
set -g @plugin 'datamadsen/nunchux'
```

Then `prefix + I` to install.

<!-- vim: set ft=markdown ts=2 sw=2 et: -->
