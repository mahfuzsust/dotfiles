#!/usr/bin/env zsh
# fzf --bind reload helper for Ctrl+F / Ctrl+N (query = $1, search path = $2)
set -f

export RIPGREP_CONFIG_PATH="${RIPGREP_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/ripgrep/ripgreprc}"

DOTFILES_SHELL="${DOTFILES_SHELL:-$HOME/.config/shell}"
[[ -f "$DOTFILES_SHELL/s" ]] || exit 0
source "$DOTFILES_SHELL/s"

_fzf_rg_fzf_source "${1:-}" "${2:-.}"
