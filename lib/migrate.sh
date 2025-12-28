#!/usr/bin/env bash
#
# lib/migrate.sh - Config migration from old to new format
#

# Guard against double-sourcing
[[ -n "${NUNCHUX_LIB_MIGRATE_LOADED:-}" ]] && return
NUNCHUX_LIB_MIGRATE_LOADED=1

# Check if config file uses old format (sections without type: prefix)
is_old_config_format() {
    local config_file="$1"
    [[ ! -f "$config_file" ]] && return 1

    # Look for section headers that aren't [settings] and don't have type: prefix
    grep -qE '^\[([a-zA-Z0-9_/-]+)\]$' "$config_file" || return 1

    # Check if any non-settings section lacks type prefix
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            local section="${BASH_REMATCH[1]}"
            # Skip special global sections
            [[ "$section" == "settings" || "$section" == "taskrunner" ]] && continue
            # If section doesn't have a colon, it's old format
            if [[ "$section" != *:* ]]; then
                return 0
            fi
        fi
    done < "$config_file"

    return 1
}

# Convert old config format to new format
convert_config() {
    local config_file="$1"
    local output=""
    local sections_with_children=()
    local plugin_settings=()
    local section_order=0

    # First pass: identify submenu parents (sections that have children with /)
    while IFS= read -r line; do
        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            local section="${BASH_REMATCH[1]}"
            if [[ "$section" == */* ]]; then
                local parent="${section%%/*}"
                local found=0
                for p in "${sections_with_children[@]}"; do
                    [[ "$p" == "$parent" ]] && found=1 && break
                done
                [[ $found -eq 0 ]] && sections_with_children+=("$parent")
            fi
        fi
    done < "$config_file"

    # Second pass: convert the config
    local in_settings=0
    local pending_section=""
    local pending_lines=""
    local pending_order=0

    process_pending_section() {
        if [[ -z "$pending_section" ]]; then
            return
        fi

        local section="$pending_section"
        local lines="$pending_lines"
        local order="$pending_order"

        # Determine section type
        local new_section=""
        if [[ "$section" == "settings" ]]; then
            new_section="[settings]"
        elif [[ "$section" == *:* ]]; then
            new_section="[$section]"
        elif [[ "$lines" == *"directory ="* || "$lines" == *"directory="* ]]; then
            new_section="[dirbrowser:$section]"
        elif [[ "$lines" == *"cmd ="* || "$lines" == *"cmd="* ]]; then
            new_section="[app:$section]"
        else
            local is_parent=0
            for p in "${sections_with_children[@]}"; do
                [[ "$p" == "$section" ]] && is_parent=1 && break
            done
            if [[ $is_parent -eq 1 ]]; then
                new_section="[menu:$section]"
            else
                new_section="[app:$section]"
            fi
        fi

        output+="$new_section"$'\n'
        if [[ "$section" != "settings" ]]; then
            output+="order = $order"$'\n'
        fi
        output+="$lines"
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^\[([^\]]+)\]$ ]]; then
            process_pending_section
            pending_section="${BASH_REMATCH[1]}"
            pending_lines=""

            if [[ "$pending_section" == "settings" ]]; then
                in_settings=1
            else
                in_settings=0
                ((section_order += 10))
                pending_order=$section_order
            fi
            continue
        fi

        # Handle plugin settings in [settings] - convert to taskrunner sections
        if [[ $in_settings -eq 1 ]]; then
            if [[ "$line" =~ ^[[:space:]]*(plugin_enabled_([a-z]+))[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                plugin_settings+=("${BASH_REMATCH[2]}:enabled=${BASH_REMATCH[3]}")
                continue
            elif [[ "$line" =~ ^[[:space:]]*(plugin_icon_([a-z]+))[[:space:]]*=[[:space:]]*(.*)$ ]]; then
                plugin_settings+=("${BASH_REMATCH[2]}:icon=${BASH_REMATCH[3]}")
                continue
            fi
        fi

        pending_lines+="$line"$'\n'
    done < "$config_file"

    process_pending_section

    # Add taskrunner sections from plugin settings
    declare -A taskrunner_enabled
    declare -A taskrunner_icon

    for setting in "${plugin_settings[@]}"; do
        local name="${setting%%:*}"
        local rest="${setting#*:}"
        local key="${rest%%=*}"
        local value="${rest#*=}"

        if [[ "$key" == "enabled" ]]; then
            taskrunner_enabled[$name]="$value"
        elif [[ "$key" == "icon" ]]; then
            taskrunner_icon[$name]="$value"
        fi
    done

    for name in "${!taskrunner_enabled[@]}" "${!taskrunner_icon[@]}"; do
        [[ -z "${taskrunner_enabled[$name]:-}${taskrunner_icon[$name]:-}" ]] && continue

        ((section_order += 10))
        output+=$'\n'"[taskrunner:$name]"$'\n'
        output+="order = $section_order"$'\n'
        [[ -n "${taskrunner_enabled[$name]:-}" ]] && output+="enabled = ${taskrunner_enabled[$name]}"$'\n'
        [[ -n "${taskrunner_icon[$name]:-}" ]] && output+="icon = ${taskrunner_icon[$name]}"$'\n'

        taskrunner_enabled[$name]=""
        taskrunner_icon[$name]=""
    done

    echo "$output"
}

# Show migration prompt with integrated task runner selector
show_migration_prompt() {
    local config_file="$1"
    local backup_file="${config_file}.old"
    local box_width=54
    local border_color="\033[90m"
    local reset="\033[0m"
    local runners=("just" "npm" "task")
    local runner_desc=("Justfile recipes" "package.json scripts" "Taskfile.yml tasks")
    local selected=(0 0 0)
    local cursor=0

    box_line() {
        local content="$1"
        local term_width=$(tput cols)
        local padding=$(( (term_width - box_width) / 2 ))
        [[ $padding -gt 0 ]] && printf "%*s" $padding ""
        local plain=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
        local content_len=${#plain}
        local inner_width=$((box_width - 4))
        local right_pad=$((inner_width - content_len))
        printf "${border_color}│${reset} "
        printf "%b" "$content"
        printf "%*s" $right_pad ""
        printf " ${border_color}│${reset}\n"
    }

    box_top() {
        local term_width=$(tput cols)
        local padding=$(( (term_width - box_width) / 2 ))
        [[ $padding -gt 0 ]] && printf "%*s" $padding ""
        printf "${border_color}╭"
        printf '─%.0s' $(seq 1 $((box_width - 2)))
        printf "╮${reset}\n"
    }

    box_bottom() {
        local term_width=$(tput cols)
        local padding=$(( (term_width - box_width) / 2 ))
        [[ $padding -gt 0 ]] && printf "%*s" $padding ""
        printf "${border_color}╰"
        printf '─%.0s' $(seq 1 $((box_width - 2)))
        printf "╯${reset}\n"
    }

    box_empty() { box_line ""; }

    draw_prompt() {
        clear
        local height=$(tput lines)
        local top_padding=$(( (height - 22) / 2 ))
        for ((i=0; i<top_padding; i++)); do echo; done

        box_top
        box_empty
        box_line "\033[1;33m       Config Migration Required\033[0m"
        box_empty
        box_line "\033[90mYour config uses the old format.\033[0m"
        box_line "\033[90mNunchux will update it (backup saved).\033[0m"
        box_empty
        box_line "\033[90mTask runners now require explicit opt-in.\033[0m"
        box_line "\033[90mSelect which ones to enable:\033[0m"
        box_empty

        for i in "${!runners[@]}"; do
            local check=" "
            [[ ${selected[$i]} -eq 1 ]] && check="✓"
            local pointer="  "
            local name_color="\033[0m"
            if [[ $cursor -eq $i ]]; then
                pointer="\033[36m▶\033[0m "
                name_color="\033[1m"
            fi
            local checkbox="\033[90m[\033[0m${check}\033[90m]\033[0m"
            box_line "${pointer}${checkbox} ${name_color}${runners[$i]}\033[0m \033[90m- ${runner_desc[$i]}\033[0m"
        done

        box_empty
        box_line "\033[90m[↑/↓] Navigate  [Space] Toggle\033[0m"
        box_line "\033[1;32m[Enter]\033[0m Migrate  \033[1;31m[Esc]\033[0m Exit"
        box_empty
        box_bottom
    }

    tput civis 2>/dev/null || true
    draw_prompt

    while true; do
        IFS= read -rsn1 key
        if [[ -z "$key" ]]; then
            # Enter - perform migration
            tput cnorm 2>/dev/null || true

            cp "$config_file" "$backup_file"

            # Check for vim modeline at end of ORIGINAL file before conversion
            local modeline=""
            local last_line
            last_line=$(tail -1 "$config_file")
            if [[ "$last_line" =~ ^#.*vim: ]]; then
                modeline="$last_line"
            fi

            # Convert config (filter out modeline if present)
            if [[ -n "$modeline" ]]; then
                local temp_file="${config_file}.tmp"
                grep -v "^#.*vim:" "$config_file" > "$temp_file"
                convert_config "$temp_file" > "${config_file}.new"
                rm -f "$temp_file"
            else
                convert_config "$config_file" > "${config_file}.new"
            fi
            mv "${config_file}.new" "$config_file"

            # Append selected taskrunners
            local has_runners=0
            for i in "${!runners[@]}"; do
                if [[ ${selected[$i]} -eq 1 ]]; then
                    if [[ $has_runners -eq 0 ]]; then
                        echo "" >> "$config_file"
                        echo "# Task runners (enabled during migration)" >> "$config_file"
                        has_runners=1
                    fi
                    echo "" >> "$config_file"
                    echo "[taskrunner:${runners[$i]}]" >> "$config_file"
                    echo "enabled = true" >> "$config_file"
                fi
            done

            # Restore vim modeline at end
            if [[ -n "$modeline" ]]; then
                echo "" >> "$config_file"
                echo "$modeline" >> "$config_file"
            fi

            clear
            local height=$(tput lines)
            local top_padding=$(( (height - 10) / 2 ))
            for ((i=0; i<top_padding; i++)); do echo; done

            box_top
            box_empty
            box_line "\033[1;32m         Config migrated!\033[0m"
            box_empty
            box_line "\033[90mBackup: ${backup_file}\033[0m"
            box_empty
            box_line "\033[90mPress any key to continue...\033[0m"
            box_empty
            box_bottom
            read -n 1 -s
            exit 0
        fi

        case "$key" in
            $'\x1b')
                read -rsn2 -t 0.01 seq
                if [[ -z "$seq" ]]; then
                    # Plain Escape - exit
                    tput cnorm 2>/dev/null || true
                    exit 0
                fi
                case "$seq" in
                    '[A') ((cursor > 0)) && ((cursor--)) ;;
                    '[B') ((cursor < ${#runners[@]} - 1)) && ((cursor++)) ;;
                esac
                ;;
            ' ')
                # Toggle with space
                if [[ ${selected[$cursor]} -eq 0 ]]; then
                    selected[$cursor]=1
                else
                    selected[$cursor]=0
                fi
                ;;
            k) ((cursor > 0)) && ((cursor--)) ;;
            j) ((cursor < ${#runners[@]} - 1)) && ((cursor++)) ;;
        esac
        draw_prompt
    done
}

# Main migration check - call this before loading config
check_and_migrate_config() {
    local config_file
    config_file=$(get_config_file)

    [[ -z "$config_file" ]] && return 0
    [[ ! -f "$config_file" ]] && return 0

    if is_old_config_format "$config_file"; then
        show_migration_prompt "$config_file"
    fi

    return 0
}
