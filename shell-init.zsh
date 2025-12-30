# Nunchux shell integration for Zsh
# Source this in your .zshrc:
#   source ~/.tmux/plugins/nunchux/shell-init.zsh
#
# This saves your shell environment after each command, so apps
# launched via nunchux inherit PATH, nvm, pyenv, custom exports, etc.

if [[ -n "$TMUX_PANE" ]]; then
    _nunchux_save_env() {
        env > "/tmp/nunchux-env-$TMUX_PANE" 2>/dev/null
    }
    precmd_functions+=(_nunchux_save_env)

    # Clean up env file when shell exits
    trap 'rm -f "/tmp/nunchux-env-$TMUX_PANE" 2>/dev/null' EXIT
fi

# vim: ft=bash ts=2 sw=2 et
