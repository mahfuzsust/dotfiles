# Shared live ripgrep helpers for fzf (sourced by config/shell/s and rg-fzf-reload.zsh).

_fzf_rg_emit_relative_lines() {
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if [[ "$line" == ./* ]]; then
      line="${line#./}"
    fi
    print -r -- "$line"
  done
}

# query: shell words passed to rg (e.g. -i -t md TODO).
_fzf_rg_fzf_source() {
  local query="$1" target="${2:-.}"
  local target_abs="${target:A}"

  [[ -n "$query" ]] || return 0
  [[ -e "$target" ]] || return 0

  (
    cd "${target_abs}" || exit 0
    export RIPGREP_CONFIG_PATH="${RIPGREP_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/ripgrep/ripgreprc}"
    local -a rg_argv
    rg_argv=("${(@Q)${(z)query}}")
    (( ${#rg_argv[@]} )) || return 0
    command rg "${rg_argv[@]}" --line-number --no-heading --color=never -- . 2>/dev/null
  ) | _fzf_rg_emit_relative_lines
}
