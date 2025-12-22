# nunchux :-)

A smart tmux app launcher that gives you quick access to your favorite TUI apps
and project tasks. Think of it as a command palette for your terminal life.

## What it can do

Launch your apps in popups or windows, and switch to them if they're already
running. No more hunting through tmux windows to find where you left lazygit.

* Show running status for each app (● running, ○ stopped)
* Open apps in popups (Enter) or windows (Ctrl-O)
* Switch to running apps instead of opening duplicates
* Kill running apps with Ctrl-X
* Dynamic status info (git changes, docker containers, system load, etc.)

### Justfile integration

If you're in a directory with a justfile, nunchux will show your recipes right
there in the menu. Select one and it runs in your current pane so you can see
the output. No more typing `just build` like a caveman.

### package.json scripts

Same deal for npm scripts. If there's a package.json, you'll see your scripts
in the menu. Select and run.

## What it looks like

```
┌─ nunchux ─────────────────────────────────────────┐
│ Enter: popup | Ctrl-O: window | Ctrl-X: kill      │
│  >                                                │
│   ●  btop          load: 0.42 | ram: 12GB free    │
│   ○  git           (3 changed)                    │
│   ○  docker        (2 running)                    │
│   ○  files         (~/.config)                    │
│   ─── just ───────────────────                    │
│   »  build                                        │
│   »  test                                         │
│   »  deploy                                       │
└───────────────────────────────────────────────────┘
```

## How to install it

Use [TPM](https://github.com/tmux-plugins/tpm) for a smooth experience. Add
this to your tmux.conf:

```
set -g @plugin 'datamadsen/nunchux'
```

Then hit `prefix + I` and you're good to go.

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

Create a config file at `~/.config/nunchux/config` (or `~/.nunchuxrc`):

```ini
[settings]
icon_running = ●
icon_stopped = ○
menu_width = 60%
menu_height = 50%
popup_width = 90%
popup_height = 90%
just_enabled = true
npm_enabled = true

[btop]
cmd = btop
status = load=$(cut -d' ' -f1 /proc/loadavg); echo "load: $load"

[git]
cmd = lazygit
status = n=$(git status -s 2>/dev/null | wc -l); [[ $n -gt 0 ]] && echo "($n changed)"

[docker]
cmd = lazydocker
status = n=$(docker ps -q 2>/dev/null | wc -l); [[ $n -gt 0 ]] && echo "($n running)"

[notes]
cmd = nvim ~/notes
width = 80
height = 60
```

### Available options

In `[settings]`:
* `icon_running` / `icon_stopped` - status indicators
* `menu_width` / `menu_height` - dimensions for the nunchux menu popup
* `popup_width` / `popup_height` - default dimensions for app popups
* `just_enabled` / `npm_enabled` - toggle integrations
* `fzf_*` - customize fzf appearance

Per app:
* `cmd` - command to run (required)
* `desc` - description shown in menu
* `width` / `height` - popup dimensions for this app
* `status` - shell command for dynamic status
* `status_script` - path to script for complex status

### Line continuation

For long status commands, use `\` to continue on the next line:

```ini
[btop]
cmd = btop
status = load=$(cut -d' ' -f1 /proc/loadavg); \
         ram=$(free -g | awk '/Mem/{print $7}'); \
         echo "load: $load | ram: ${ram}GB"
```

## Dependencies

* tmux (duh)
* fzf
* jq (optional, for npm scripts)
* just (optional, for justfile integration)
