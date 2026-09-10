#!/usr/bin/env zsh
[[ -f "$HOME/.tmux.conf" ]] && tmux source-file "$HOME/.tmux.conf" 2>/dev/null
exec tmux new-session -A -s main
