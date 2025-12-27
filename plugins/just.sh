#!/usr/bin/env bash
# nunchux plugin: justfile integration

plugin_name() { echo "just"; }
plugin_label() { echo "just"; }
plugin_icon() { echo "🤖"; }

plugin_items() {
    command -v just &>/dev/null || return
    # just --list format: "recipe # description" or just "recipe"
    just --list --unsorted 2>/dev/null | while read -r line; do
        # Skip header line "Available recipes:"
        [[ "$line" == Available* ]] && continue
        [[ -z "$line" ]] && continue
        # Parse recipe name and optional description
        local recipe desc
        recipe=$(echo "$line" | awk '{print $1}')
        desc=$(echo "$line" | sed -n 's/^[^ ]* *# *//p')
        printf '%s\t%s\t%s\n' "$recipe" "just $recipe" "$desc"
    done
}
