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
| `fzf_prompt` | ` ` | Prompt shown in fzf |
| `fzf_pointer` | `▶` | Pointer for selected item |
| `fzf_border` | `rounded` | Border style (`rounded`, `sharp`, `double`, etc.) |
| `fzf_border_label` | ` nunchux ` | Label shown in border |
| `fzf_colors` | (see below) | fzf color scheme |
| `cache_ttl` | `60` | Seconds before cache refresh (0 to disable) |
| `exclude_patterns` | (see below) | Patterns to exclude from directory browsers |
| `primary_key` | `enter` | Key for primary action (popup/edit) |
| `secondary_key` | `ctrl-o` | Key for secondary action (window) |

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

## Ordering

By default, items appear in the order they're defined in the config file. Use the `order` property to override this:

```ini
[app:htop]
order = 10

[app:lazygit]
order = 5    # Appears before htop despite being defined after
```

Lower values appear first. Items without `order` are sorted by config file position (after items with explicit orders).

The `order` property is available on all section types: apps, menus, dirbrowsers, and taskrunners.

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
| `order` | No | Explicit sort order (lower = first) |

### Variables in cmd and on_exit

| Variable | Description |
|----------|-------------|
| `{pane_id}` | Parent tmux pane ID |
| `{tmp}` | Fresh temp file path |
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
width = 90
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
| `width` | `90` | Popup width |
| `height` | `80` | Popup height |
| `order` | (none) | Explicit sort order (lower = first) |

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
| `order` | (none) | Explicit sort order (lower = first) |

### Available Task Runners

| Name | Description | Detection |
|------|-------------|-----------|
| `just` | [just](https://github.com/casey/just) command runner | `justfile` in current directory |
| `npm` | npm scripts | `package.json` with scripts |
| `task` | [Task](https://taskfile.dev) runner | `Taskfile.yml` in current directory |

### Taskrunner Window Behavior

Task runner commands run in dedicated tmux windows (not popups):

- **Primary action** (Enter): Runs task in a background window, you stay in current window
- **Secondary action** (Ctrl-O): Runs task and switches to that window
- **Ctrl-X**: Kills the task's window

Window titles show the task name and status: `just » build 🔄` (running), `just » build ✅` (success), `just » build ❌` (failed).

Re-running the same task reuses its existing window instead of creating a new one.

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

Example with nerd fonts:
```ini
[taskrunner]
icon_running =
icon_success =
icon_failed =
```
