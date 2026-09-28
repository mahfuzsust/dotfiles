#!/usr/bin/env zsh
# fzf --bind reload helper (env: FZF_QUERY, FZF_RG_TARGET)
set -f

export RIPGREP_CONFIG_PATH="${RIPGREP_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/ripgrep/ripgreprc}"

query="${FZF_QUERY:-${FZF_RG_QUERY:-}}"
target="${FZF_RG_TARGET:-.}"

lib="${XDG_CONFIG_HOME:-$HOME/.config}/fzf/rg-fzf-lib.zsh"
[[ -f "$lib" ]] || exit 0
source "$lib"

_fzf_rg_fzf_source "$query" "$target"
exit 0
