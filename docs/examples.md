# Examples

Real-world configuration examples to get you started.

## Basic Apps

### Git with [lazygit](https://github.com/jesseduffield/lazygit)

Simple status showing changed file count:

```ini
[app:git]
cmd = lazygit
status = n=$(git status -s 2>/dev/null | wc -l | tr -d ' '); [[ $n -gt 0 ]] && echo "($n changed)"
```

### Docker with [lazydocker](https://github.com/jesseduffield/lazydocker)

```ini
[app:docker]
cmd = lazydocker
status = n=$(docker ps -q 2>/dev/null | wc -l | tr -d ' '); [[ $n -gt 0 ]] && echo "($n running)"
```

## Advanced Status Scripts

### Git with full details

Shows changed files, untracked files, and ahead/behind status:

```ini
[app:git]
cmd = lazygit
status = cd "$(tmux display-message -p '#{pane_current_path}')"; \
         changed=$(git status -s 2>/dev/null | grep -vc '^??' | tr -d ' '); \
         untracked=$(git status -s 2>/dev/null | grep -c '^??' | tr -d ' '); \
         ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0); \
         behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo 0); \
         parts=(); \
         [[ $changed -gt 0 ]] && parts+=("${changed} changed"); \
         [[ $untracked -gt 0 ]] && parts+=("${untracked} untracked"); \
         [[ $ahead -gt 0 ]] && parts+=("↑${ahead}"); \
         [[ $behind -gt 0 ]] && parts+=("↓${behind}"); \
         if [[ ${#parts[@]} -gt 0 ]]; then IFS=", "; echo "(${parts[*]})"; else echo "(all up to date)"; fi
```

### Calendar with [calcurse](https://github.com/lfos/calcurse)

Shows your next upcoming event:

```ini
[app:calendar]
cmd = calcurse
width = 80
height = 70
status = next=$(calcurse -r7 2>/dev/null | awk '/^[0-9]/{d=$1;getline;if(/->/)t=$2;getline;m=$0;gsub(/^[[:space:]]+/,"",m);if(length(m)>40)m=substr(m,1,40)"...";print d,t,m;exit}'); [[ -n "$next" ]] && echo "($next)"
```

## Using Helper Functions

Nunchux provides `ago`, `lines`, and `nearest` helpers.

### Notes with nearest

Finds the nearest `notes.md` by walking up the directory tree:

```ini
[app:notes]
cmd = bash -c 'f=$(nearest notes.md) && exec nvim "$f" || { echo "No notes.md found"; sleep 2; }'
width = 80
height = 60
status = f=$(nearest notes.md) && echo "(${f/#$HOME/\~}: $(lines "$f"), $(ago "$f"))"
```

### Todos with line count and age

```ini
[app:todos]
cmd = nvim ~/todos.md
width = 70
height = 50
status = echo "(~/todos.md: $(lines ~/todos.md), $(ago ~/todos.md))"
```

## File Manager with Directory Sync

Using [yazi](https://github.com/sxyazi/yazi) wrapped in nvim (workaround for tmux popup issues), with `on_exit` to cd the parent pane:

```ini
[app:files]
cmd = nvim --clean -c 'set laststatus=0 cmdheight=0 noshowmode noruler signcolumn=no nonumber' -c 'terminal yazi --cwd-file={tmp}' -c 'startinsert' -c 'autocmd TermClose * qa!'
status = echo "($(tmux display-message -p '#{pane_current_path}' | sed "s|$HOME|~|"))"
height = 50
width = 60
on_exit = cwd=$(cat {tmp} 2>/dev/null); \
  if [[ -d "$cwd" ]]; then \
    cmd=$(tmux display-message -t {pane_id} -p '#{pane_current_command}'); \
    [[ "$cmd" =~ ^(bash|zsh|fish|sh)$ ]] && tmux send-keys -t {pane_id} "cd \"$cwd\"" Enter; \
  fi; \
  rm -f {tmp}
```

## Directory Browser

Browse and edit config files with folder grouping:

```ini
[dirbrowser:config]
directory = ~/dotfiles
depth = 2
sort = modified-folder
sort_direction = descending
width = 90
height = 80
cache_ttl = 300
```

## Submenus

### System submenu with rich status

The parent shows system stats, children are system tools:

Tools used:
[btop](https://github.com/aristocratos/btop),
[impala](https://github.com/pythops/impala),
[wiremix](https://github.com/e-tho/wiremix),
[bluetuith](https://github.com/darkhz/bluetuith),
[bandwhich](https://github.com/imsnif/bandwhich),
[duf](https://github.com/muesli/duf),
[ncdu](https://dev.yorhel.nl/ncdu),
[nvtop](https://github.com/Syllo/nvtop)

```ini
[menu:system]
status = load=$(cut -d' ' -f1 /proc/loadavg); \
         ram=$(awk '/MemAvailable/{printf "%.0f", $2/1024/1024}' /proc/meminfo); \
         disk=$(df /home --output=avail 2>/dev/null | tail -1 | awk '{printf "%.0f", $1/1024/1024}'); \
         wifi=$(iwgetid -r 2>/dev/null); \
         bat=$(acpi -b 2>/dev/null | head -1); \
         if [[ "$bat" == *Discharging* ]]; then bstat="| 󱊣 $(echo "$bat" | grep -oP '\d+:\d+(?=:\d+)')"; \
         elif [[ "$bat" == *Charging* ]]; then bstat="| 󱊣 $(echo "$bat" | grep -oP '\d+:\d+(?=:\d+)') ⚡"; \
         else bstat=''; fi; \
         wstat=""; [[ -n "$wifi" ]] && wstat="| 󰖩 $wifi "; \
         echo "󰍛 $load | 󰘚 ${ram}GB | 󰋜 ${disk}GB $wstat$bstat"

[app:system/btop]
cmd = btop
desc = Task manager

[app:system/impala]
cmd = impala
desc = WiFi manager

[app:system/wiremix]
cmd = wiremix
desc = Audio mixer

[app:system/bluetuith]
cmd = bluetuith
desc = Bluetooth manager

[app:system/bandwhich]
cmd = sudo bandwhich
desc = Bandwidth by process

[app:system/duf]
cmd = duf -only local | less -R
desc = Disk usage
width = 60
height = 30

[app:system/journalctl]
cmd = journalctl -f
desc = Follow system logs

[app:system/ncdu]
cmd = ncdu
desc = Disk usage analyzer

[app:system/nvtop]
cmd = nvtop
desc = GPU monitoring
```

## Task Runners

Enable task runners to show project tasks in the menu:

```ini
# Enable just and npm task runners
[taskrunner:just]
enabled = true
icon = 🤖

[taskrunner:npm]
enabled = true
icon = 📦

# Customize status icons (optional)
[taskrunner]
icon_running = 🔄
icon_success = ✅
icon_failed = ❌
```

With nerd fonts:

```ini
[taskrunner:just]
enabled = true
icon =

[taskrunner:npm]
enabled = true
icon =

[taskrunner]
icon_running =
icon_success =
icon_failed =
```

## Simple Apps

Apps that just need a command and description:

```ini
[app:todoist]
cmd = terminalist       # https://github.com/akarsh1995/terminalist
desc = Tick things off
width = 80
height = 70

[app:hacker news]
cmd = hackernews_tui    # https://github.com/aome510/hackernews-TUI
desc = The front page of the internet (for nerds)

[app:reddix]
cmd = reddix            # https://github.com/darkhz/reddix
desc = Down the rabbit hole
```
