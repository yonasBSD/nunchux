# Configuration

Nunchux uses an INI-style configuration file with typed sections.

## Config Location

Nunchux searches for config in this order:

1. **Local `.nunchuxrc`** - searches upward from current directory (like `.gitignore`)
2. **`NUNCHUX_RC_FILE`** - environment variable override
3. **`~/.config/nunchux/config`** - user config

This allows per-project configs. Place a `.nunchuxrc` in your project root to have
project-specific apps and taskrunners appear when you're in that directory.

## Config Format

Sections use `[type:name]` syntax to declare their type explicitly:

```ini
[settings]
popup_width = 90%

[app:lazygit]
cmd = lazygit

[menu:system]
desc = System tools

[app:system/htop]
cmd = htop

[dirbrowser:configs]
directory = ~/.config

[taskrunner:just]
enabled = true
```

## Settings

The `[settings]` section controls global behavior:

| Setting | Default | Description |
|---------|---------|-------------|
| `icon_running` | `●` | Icon shown next to running apps |
| `icon_stopped` | `○` | Icon shown next to stopped apps |
| `menu_width` | `60%` | Width of the app selector menu |
| `menu_height` | `50%` | Height of the app selector menu |
| `popup_width` | `90%` | Default width for app popups |
| `popup_height` | `90%` | Default height for app popups |
| `max_popup_width` | (none) | Maximum popup width in columns |
| `max_popup_height` | (none) | Maximum popup height in rows |
| `primary_key` | `enter` | Key for primary action |
| `secondary_key` | `ctrl-o` | Key for secondary action |
| `primary_action` | `popup` | Default primary action (see below) |
| `secondary_action` | `window` | Default secondary action (see below) |
| `fzf_prompt` | ` ` | Prompt shown in fzf |
| `fzf_pointer` | `▶` | Pointer for selected item |
| `fzf_border` | `rounded` | Border style (`rounded`, `sharp`, `double`, etc.) |
| `label` | `nunchux` | Label shown in borders and popup titles |
| `fzf_colors` | (see below) | fzf color scheme |
| `cache_ttl` | `60` | Seconds before cache refresh (0 to disable) |
| `exclude_patterns` | (see below) | Patterns to exclude from directory browsers |
| `show_cwd` | `true` | Show current working directory in menu label |
| `toggle_shortcuts_key` | `ctrl-/` | Key to toggle shortcut column visibility |

### Dimensions

Dimensions can be specified as percentages or absolute values:

```ini
[settings]
menu_width = 60         # 60 columns (use 60% for percentage)
menu_height = 50%       # 50% of terminal height

popup_width = 90%
popup_height = 90%
max_popup_width = 160   # Cap app popups at 160 columns
max_popup_height = 50   # Cap app popups at 50 rows
```

On large screens, percentage-based dimensions can result in overly large app popups. Use `max_popup_*` settings to cap dimensions. The percentage is calculated against the current tmux window size, then clamped to the maximum if exceeded. This applies to app popups and dirbrowser popups, not to the menu itself.

### Action Types

| Action | Description |
|--------|-------------|
| `popup` | Open in a tmux popup overlay |
| `window` | Open in a new tmux window with focus |
| `background_window` | Open in a new tmux window, stay in current pane |
| `pane_right` | Open in a pane to the right |
| `pane_left` | Open in a pane to the left |
| `pane_above` | Open in a pane above |
| `pane_below` | Open in a pane below |

Different item types have different default actions:

| Type | Primary Default | Secondary Default |
|------|-----------------|-------------------|
| Apps | `popup` | `window` |
| Taskrunners | `window` | `background_window` |
| Dirbrowsers | `popup` | `window` |

You can override the default actions globally in `[settings]`, or per-item.

### Direct Action Shortcuts

In addition to primary/secondary keys, you can configure dedicated shortcuts that always trigger a specific action:

| Setting | Description |
|---------|-------------|
| `popup_key` | Always open in popup |
| `window_key` | Always open in window |
| `background_window_key` | Always open in background window |
| `pane_right_key` | Always open in pane to the right |
| `pane_left_key` | Always open in pane to the left |
| `pane_above_key` | Always open in pane above |
| `pane_below_key` | Always open in pane below |

These are disabled by default (empty). Enable the ones you want:

```ini
[settings]
popup_key = ctrl-p
window_key = ctrl-w
background_window_key = ctrl-b
pane_right_key = ctrl-right
pane_left_key = ctrl-left
pane_above_key = ctrl-up
pane_below_key = ctrl-down
```

When configured, these shortcuts appear in the help header (toggle with `Ctrl-/`).

These keys are reserved and cannot be used as item shortcuts.

### Action Menu

Press `Ctrl-J` (default) to open a menu for selecting how to launch the highlighted item. This provides quick access to all launch modes without configuring individual shortcuts.

| Setting | Default | Description |
|---------|---------|-------------|
| `action_menu_key` | `ctrl-j` | Key to open action selection menu |

Set to empty to disable:

```ini
[settings]
action_menu_key =
```

Note: `ctrl-m` cannot be used as it's equivalent to Enter in terminals.

### Default fzf_colors

```
fg+:white:bold,bg+:-1,hl:cyan,hl+:cyan:bold,pointer:cyan,marker:green,header:gray,border:gray
```

### Default exclude_patterns

```
.git, node_modules, Cache, cache, .cache, GPUCache, CachedData, blob_storage,
Code Cache, Session Storage, Local Storage, IndexedDB, databases, *.db, *.db-*,
*.sqlite*, *.log, *.png, *.jpg, *.jpeg, *.gif, *.ico, *.webp, *.woff*, *.ttf,
*.lock, lock, *.pid
```

Patterns starting with `*` match filenames. Others exclude both directories and files with that name.

## Keyboard Shortcuts

Assign keyboard shortcuts to launch items directly from the menu without navigating:

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

### Viewing Shortcuts

Press `Ctrl-/` (configurable via `toggle_shortcuts_key`) to toggle the shortcut column visibility. When shown, shortcuts appear on the left:

```
[ctrl-g] │ ○ lazygit       Git TUI
         │ ○ htop          Process viewer
[ctrl-s] │ ▸ system        System tools
```

### Reserved Keys

These keys cannot be used as shortcuts:

- `enter`, `esc`, `ctrl-x` - Used by fzf/nunchux
- `/` - Used for jump mode
- Your configured `primary_key` and `secondary_key`

### Validation

Nunchux validates shortcuts at startup:

- **Invalid keys** - Keys not supported by fzf (e.g., `shift-enter`)
- **Reserved keys** - Keys used by nunchux itself
- **Duplicates** - Same shortcut assigned to multiple items

If any shortcuts are invalid, an error screen shows all issues.

### Supported Keys

Common shortcut keys: `ctrl-a` through `ctrl-z`, `alt-a` through `alt-z`, `f1` through `f12`, `tab`, `space`.

Note: `shift-enter` and `ctrl-enter` are **not supported** by most terminals.

## Ordering

Use `[order]` sections to control item order declaratively:

```ini
[order]
lazygit
config
taskrunner:just
system
taskrunner:npm
docker
htop
# Items not listed appear alphabetically after these
```

Items are displayed in the order listed. Unlisted items are appended alphabetically.

Taskrunners use the `taskrunner:name` format (e.g., `taskrunner:just`). All tasks for that runner appear at that position. Individual tasks within each runner remain in their discovery order.

### Submenu Ordering

Control item order within submenus:

```ini
[order:system]
duf
ncdu
btop
journalctl
```

### Ordering Notes

- Items not listed in `[order]` appear alphabetically after ordered items
- Non-existent items in `[order]` sections are silently ignored
- Apps, dirbrowsers, submenus, and taskrunners can all be listed in `[order]`

## Apps

Use `[app:name]` to define an app:

```ini
[app:lazygit]
cmd = lazygit
desc = Git TUI
width = 95
height = 95
status = n=$(git status -s 2>/dev/null | wc -l); [[ $n -gt 0 ]] && echo "($n changed)"
on_exit = echo "done"
```

| Option | Required | Description |
|--------|----------|-------------|
| `cmd` | Yes | Command to run |
| `desc` | No | Description shown in menu |
| `width` | No | Popup width (overrides global) |
| `height` | No | Popup height (overrides global) |
| `status` | No | Shell command for dynamic status text |
| `status_script` | No | Path to script for complex status |
| `on_exit` | No | Command to run after app exits |
| `primary_action` | No | Override primary action for this app |
| `secondary_action` | No | Override secondary action for this app |
| `shortcut` | No | Keyboard shortcut (e.g., `ctrl-g`) |

### Variables in cmd and on_exit

| Variable | Description |
|----------|-------------|
| `{pane_id}` | Parent tmux pane ID (for `tmux send-keys -t {pane_id}`) |
| `{tmp}` | Fresh temp file path (for passing data to on_exit) |
| `{dir}` | Starting directory |

## Submenus

Use `[menu:name]` for the parent menu and `[app:parent/child]` for children:

```ini
[menu:system]
desc = System tools
status = echo "load: $(cut -d' ' -f1 /proc/loadavg)"

[app:system/htop]
cmd = htop
desc = Process viewer

[app:system/ncdu]
cmd = ncdu
desc = Disk usage
```

The `[menu:system]` appears in the main menu. Selecting it opens a submenu with its children.

Menu sections support:

- `status` - Dynamic status text
- `desc` - Description
- `cache_ttl` - Override cache duration for this submenu
- `shortcut` - Keyboard shortcut (e.g., `ctrl-s`)
- `order` - Explicit sort order (lower = first)

## Directory Browsers

Use `[dirbrowser:name]` to create a file browser:

```ini
[dirbrowser:configs]
directory = ~/.config
depth = 2
sort = modified-folder
sort_direction = descending
glob = *.conf
cache_ttl = 300
width = 90 # Use 90% for 90%. 90 will be columns
height = 80
```

| Option | Default | Description |
|--------|---------|-------------|
| `directory` | (required) | Path to browse |
| `depth` | `1` | How many levels deep to search |
| `sort` | `modified` | Sort mode (see below) |
| `sort_direction` | `descending` | `ascending` or `descending` |
| `glob` | (none) | Filter files by pattern (e.g., `*.conf`) |
| `cache_ttl` | `300` | Cache duration in seconds |
| `width` | `90` | Popup width (percentage or columns) |
| `height` | `80` | Popup height (percentage or columns) |
| `primary_action` | `popup` | Override primary action |
| `secondary_action` | `window` | Override secondary action |
| `shortcut` | (none) | Keyboard shortcut (e.g., `ctrl-c`) |

### Sort Modes

| Mode | Description |
|------|-------------|
| `modified` | Files sorted by modification time |
| `modified-folder` | Folders grouped by most recent file, then files by recency |
| `alphabetical` | Sorted by folder/filename |

Selected files open in `$VISUAL`, `$EDITOR`, or `nvim` (first available).

## Task Runners

Use `[taskrunner:name]` to enable task runners for project automation:

```ini
[taskrunner:just]
enabled = true
icon = 🤖

[taskrunner:npm]
enabled = true
icon = 📦

[taskrunner:task]
enabled = false
```

Task runners are **disabled by default** and must be explicitly enabled.

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `false` | Whether to show this task runner |
| `icon` | (runner default) | Icon shown in divider line |
| `label` | (runner name) | Label shown in menu |
| `primary_action` | `window` | Override primary action |
| `secondary_action` | `background_window` | Override secondary action |

### Available Task Runners

| Name | Description | Detection |
|------|-------------|-----------|
| `just` | [just](https://github.com/casey/just) command runner | `justfile` in current directory |
| `npm` | npm scripts | `package.json` with scripts |
| `task` | [Task](https://taskfile.dev) runner | `Taskfile.yml` in current directory |

### Taskrunner Window Behavior

Task runner commands run in dedicated tmux windows (not popups by default):

- **Primary action** (Enter): Runs task and switches to its window
- **Secondary action** (Ctrl-O): Runs task in background, stay in current pane
- **Ctrl-X**: Kills the task's window

Window titles show the task name and status:

- `just » build 🔄` (running)
- `just » build ✅` (success)
- `just » build ❌` (failed)

Re-running the same task reuses its existing window instead of creating a new one.

You can change this behavior per-taskrunner:

```ini
[taskrunner:npm]
enabled = true
primary_action = popup  # Run npm tasks in a popup instead
```

### Taskrunner Status Icons

Use the `[taskrunner]` section (without a name) to configure status icons globally:

```ini
[taskrunner]
icon_running = 🔄
icon_success = ✅
icon_failed = ❌
```

| Option | Default | Description |
|--------|---------|-------------|
| `icon_running` | `🔄` | Icon while task is running |
| `icon_success` | `✅` | Icon when task completes successfully |
| `icon_failed` | `❌` | Icon when task fails |

This is useful if you prefer icons from the nerd font you are using.

<!-- vim: set ft=markdown ts=2 sw=2 et: -->
