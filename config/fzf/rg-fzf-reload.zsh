#!/usr/bin/env zsh
# fzf reload-sync helper: $1 = search root, $2 = the raw fzf query ({q}, ONE argument).
# The query is split into shell words (quotes honored, no globbing) and passed to rg.
emulate -L zsh
setopt localoptions no_aliases
set -f

lib="${DOTFILES_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}}/fzf/rg-fzf-lib.zsh"
[[ -f "$lib" ]] || exit 0
source "$lib"

target="${1:-.}"
shift

# fzf hands {q} over as a single quoted string; split it like the terminal would.
rg_args=(${(Q)${(z)1}})

[[ -e "$target" ]] || exit 0
_fzf_rg_query_incomplete "${rg_args[@]}" && exit 0

rg_bin="$(_fzf_rg_bin)" || exit 1

cd "${target:A}" || exit 0
export RIPGREP_CONFIG_PATH="$(_fzf_rg_config_path)"

# </dev/null: with no path, rg searches stdin (and hangs) whenever stdin is an open pipe.
"$rg_bin" --line-number --no-heading --color=never "${rg_args[@]}" </dev/null || true
