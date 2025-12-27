#!/usr/bin/env bash
# nunchux plugin: npm scripts integration

plugin_name() { echo "npm"; }
plugin_label() { echo "npm"; }
plugin_icon() { echo "📦"; }

plugin_items() {
  command -v npm &>/dev/null || return
  # npm needs the directory context since 'npm run' doesn't search upward
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/package.json" ]]; then
      local scripts
      if command -v jq &>/dev/null; then
        scripts=$(jq -r '.scripts // {} | keys[]' "$dir/package.json" 2>/dev/null)
      else
        scripts=$(grep -oP '(?<="scripts"\s*:\s*\{)[^}]*' "$dir/package.json" 2>/dev/null |
          grep -oP '"[^"]+"\s*:' | tr -d '":' | tr -s ' ' '\n')
      fi
      while IFS= read -r script; do
        # npm scripts don't have descriptions, output empty
        [[ -n "$script" ]] && printf '%s\t%s\t\n' "$script" "cd '$dir' && npm run $script"
      done <<<"$scripts"
      return
    fi
    dir=$(dirname "$dir")
  done
}
