# Configuration

Nunchux uses an INI-style configuration file.

**Location:** `~/.config/nunchux/config` (fallback: `~/.nunchuxrc`)

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
| `just_enabled` | `true` | Show tasks from `justfile` |
| `npm_enabled` | `true` | Show scripts from `package.json` |
| `fzf_prompt` | ` ` | Prompt shown in fzf |
| `fzf_pointer` | `▶` | Pointer for selected item |
| `fzf_border` | `rounded` | Border style (`rounded`, `sharp`, `double`, etc.) |
| `fzf_border_label` | ` nunchux ` | Label shown in border |
| `fzf_colors` | (see below) | fzf color scheme |
| `cache_ttl` | `60` | Seconds before cache refresh (0 to disable) |
| `exclude_patterns` | (see below) | Patterns to exclude from directory browsers |

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

## Apps

Each `[section]` defines an app:

```ini
[lazygit]
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

### Variables in cmd and on_exit

| Variable | Description |
|----------|-------------|
| `{pane_id}` | Parent tmux pane ID |
| `{tmp}` | Fresh temp file path |
| `{dir}` | Starting directory |

## Submenus

Use `[parent/child]` naming to create submenus:

```ini
[system]
status = echo "load: $(cut -d' ' -f1 /proc/loadavg)"

[system/htop]
cmd = htop
desc = Process viewer

[system/ncdu]
cmd = ncdu
desc = Disk usage
```

The parent `[system]` appears in the main menu. Selecting it opens a submenu with its children.

Parent sections support:
- `status` - Dynamic status text
- `desc` - Description
- `cache_ttl` - Override cache duration for this submenu

## Directory Browsers

Use `directory` instead of `cmd` to create a file browser:

```ini
[configs]
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

### Sort Modes

| Mode | Description |
|------|-------------|
| `modified` | Files sorted by modification time |
| `modified-folder` | Folders grouped by most recent file, then files by recency |
| `alphabetical` | Sorted by folder/filename |

Selected files open in `$VISUAL`, `$EDITOR`, or `nvim` (first available).
