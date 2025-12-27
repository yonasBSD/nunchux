#!/usr/bin/env bash
# nunchux plugin: Taskfile integration

plugin_name() { echo "task"; }
plugin_label() { echo "task"; }
plugin_icon() { echo "✓"; }

plugin_items() {
    # Support both 'task' and 'go-task' binary names
    local task_cmd
    if command -v task &>/dev/null; then
        task_cmd="task"
    elif command -v go-task &>/dev/null; then
        task_cmd="go-task"
    else
        return
    fi

    # task --list-all --json gives us tasks with names and descriptions
    local json
    json=$("$task_cmd" --list-all --json 2>/dev/null) || return

    if command -v jq &>/dev/null; then
        echo "$json" | jq -r ".tasks[] | \"\(.name)\t$task_cmd \(.name)\t\(.desc // \"\")\""
    else
        # Fallback: parse task --list output (format: "* name: description")
        "$task_cmd" --list 2>/dev/null | grep '^\* ' | while read -r line; do
            local name desc
            name="${line#\* }"
            desc="${name#*: }"
            name="${name%%:*}"
            [[ "$desc" == "$name" ]] && desc=""
            printf '%s\t%s\t%s\n' "$name" "$task_cmd $name" "$desc"
        done
    fi
}
