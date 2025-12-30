# Nunchux shell integration for Fish
# Source this in your config.fish:
#   source ~/.tmux/plugins/nunchux/shell-init.fish
#
# This saves your shell environment after each command, so apps
# launched via nunchux inherit PATH, nvm, pyenv, custom exports, etc.

if set -q TMUX_PANE
    function _nunchux_save_env --on-event fish_postexec
        env > "/tmp/nunchux-env-$TMUX_PANE" 2>/dev/null
    end

    # Clean up env file when shell exits
    function _nunchux_cleanup --on-event fish_exit
        rm -f "/tmp/nunchux-env-$TMUX_PANE" 2>/dev/null
    end
end

# vim: ft=fish ts=2 sw=2 et
