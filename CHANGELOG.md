# Changelog

All notable changes to nunchux will be documented in this file.

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
- **Ordering control** - New `order` property on any item, lower values appear first

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
