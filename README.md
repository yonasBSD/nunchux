# nunchux :-)

A smart tmux app launcher that gives you quick access to your favorite TUI apps
and project tasks. Think of it as a command palette for your terminal life.

## What it can do

Launch your apps in popups or windows, and switch to them if they're already
running. No more hunting through tmux windows to find where you left lazygit.

* Show running status for each app (● running, ○ stopped)
* Configurable actions: open in popup, window, or background window
* Switch to running apps instead of opening duplicates
* Kill running apps with Ctrl-X
* Dynamic status info (git changes, docker containers, system load, etc.)

### Task runner integrations

Nunchux has built-in task runners that auto-detect project tools and show tasks
right in the menu. Tasks run in dedicated tmux windows with status indicators:

* `just » build 🔄` - running
* `just » build ✅` - completed successfully
* `just » build ❌` - failed

Built-in task runners:

* **just** - Justfile recipes (requires [just](https://github.com/casey/just))
* **npm** - package.json scripts (requires npm)
* **task** - Taskfile tasks (requires [task](https://taskfile.dev/) or go-task)

Task runners are disabled by default. Enable them in your config and they'll
appear when the relevant files are detected (justfile, package.json, Taskfile.yml).

## What it looks like

[![nunchux demo](https://vhs.charm.sh/vhs-4H4NyQC5bYtYGpNkb6vIaH.gif)](https://vhs.charm.sh/vhs-4H4NyQC5bYtYGpNkb6vIaH.gif)

## How to install it

Use [TPM](https://github.com/tmux-plugins/tpm) for a smooth experience. Add
this to your tmux.conf:

```
set -g @plugin 'datamadsen/nunchux'
```

Then hit `prefix + I` and you're good to go.

To update to the latest version, hit `prefix + U` and type `nunchux` (or `all`
to update all plugins).

## How to invoke it

By default the menu is invoked with `prefix + g`, but you can change it:

```
set -g @nunchux-key 'a'
```

If you want to invoke it without the prefix, e.g. with `Ctrl-Space`:

```
set -g @nunchux-key 'C-Space'
```

## Configuring your apps

Nunchux searches for config in this order:

1. `.nunchuxrc` in current directory (or any parent, like `.gitignore`)
2. `NUNCHUX_RC_FILE` environment variable
3. `~/.config/nunchux/config`

Or just run `nunchux` without a config and it will offer to create one for you.

See [docs/configuration.md](docs/configuration.md) for the full reference and
[docs/examples.md](docs/examples.md) for real-world examples.

```ini
[settings]
icon_running = ●
icon_stopped = ○
menu_width = 60%
menu_height = 50%
popup_width = 90%
popup_height = 90%
primary_action = popup
secondary_action = window

[app:btop]
cmd = btop
status = load=$(cut -d' ' -f1 /proc/loadavg); echo "load: $load"

[app:git]
cmd = lazygit
primary_action = window   # Always open lazygit in a window
status = n=$(git status -s 2>/dev/null | wc -l); [[ $n -gt 0 ]] && echo "($n changed)"

[app:docker]
cmd = lazydocker
status = n=$(docker ps -q 2>/dev/null | wc -l); [[ $n -gt 0 ]] && echo "($n running)"

[app:notes]
cmd = nvim ~/notes
width = 80
height = 60

[taskrunner:just]
enabled = true

[taskrunner:npm]
enabled = true
primary_action = background_window  # Run npm tasks in background
```

### Available options

In `[settings]`:

* `icon_running` / `icon_stopped` - status indicators
* `menu_width` / `menu_height` - dimensions for the nunchux menu popup
* `popup_width` / `popup_height` - default dimensions for app popups
* `primary_key` / `secondary_key` - keybindings (default: enter/ctrl-o)
* `primary_action` / `secondary_action` - what happens on keypress (see below)
* `fzf_*` - customize fzf appearance

**Action types:** `popup` (tmux popup), `window` (new window with focus), `background_window` (new window, stay in current pane)

Default actions by type:

* Apps: `popup` / `window`
* Taskrunners: `window` / `background_window`
* Dirbrowsers: `popup` / `window`

Per app (`[app:name]`):

* `cmd` - command to run (required)
* `desc` - description shown in menu
* `width` / `height` - popup dimensions for this app
* `status` - shell command for dynamic status
* `status_script` - path to script for complex status
* `primary_action` / `secondary_action` - override global action for this app

### Line continuation

For long status commands, use `\` to continue on the next line:

```ini
[btop]
cmd = btop
status = load=$(cut -d' ' -f1 /proc/loadavg); \
         ram=$(free -g | awk '/Mem/{print $7}'); \
         echo "load: $load | ram: ${ram}GB"
```

### Helper functions

Nunchux provides helper functions you can use in status commands:

* `ago <file>` - relative modification time (`5s ago`, `3m ago`, `2h ago`, `7d ago`)
* `lines <file>` - line count with pluralization (`1 line`, `42 lines`)
* `nearest <file>` - find file by traversing upward from current directory

```ini
[config]
cmd = nvim ~/.config/nunchux/config
status = echo "($(ago ~/.config/nunchux/config))"

[todos]
cmd = nvim ~/todos.md
status = echo "($(lines ~/todos.md))"

[notes]
cmd = bash -c 'f=$(nearest notes.md) && exec nvim "$f" || echo "Not found"'
status = f=$(nearest notes.md) && echo "($(lines "$f"), $(ago "$f"))"
```

## Shell Integration (optional)

If you use nvm, pyenv, or other tools that modify your shell environment, you'll
want apps launched via nunchux to inherit that environment.

**Why is this needed?**

Tmux popups run in tmux's *server* environment, not your shell's environment.
When you run `nvm use 18` or `export FOO=bar`, those changes only exist in your
shell - tmux doesn't know about them. There's no tmux API to "run a command
inside a pane's shell context", so we work around it with a shell hook that
saves your environment after each command. When nunchux launches an app, it
reads that saved environment.

Add this to your shell rc file:

**Bash** (`~/.bashrc`):

```bash
source ~/.tmux/plugins/nunchux/shell-init.bash
```

**Zsh** (`~/.zshrc`):

```zsh
source ~/.tmux/plugins/nunchux/shell-init.zsh
```

**Fish** (`~/.config/fish/config.fish`):

```fish
source ~/.tmux/plugins/nunchux/shell-init.fish
```

This saves your environment after each command, so apps launched from nunchux
(even from within vim or lazygit) inherit your current PATH, exports, etc.

## Dependencies

* tmux (duh)
* fzf v0.66+
* curl (for menu hot-swap)

### Optional dependencies

* jq (for npm/task runner)
* just (for justfile runner)
* task or go-task (for Taskfile runner)

<!-- vim: set ft=markdown ts=2 sw=2 et : -->
