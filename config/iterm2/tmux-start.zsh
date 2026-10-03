#!/usr/bin/env zsh
# iTerm profile entry: attach to tmux when available; always leave an interactive zsh
# when the tmux client exits (detach or last session closed) — avoids iTerm
# "[Process completed]" with no prompt.

[[ -f "$HOME/.tmux.conf" ]] && tmux source-file "$HOME/.tmux.conf" 2>/dev/null

if command -v tmux >/dev/null 2>&1; then
  tmux new-session -A -s main
fi

exec zsh -l
