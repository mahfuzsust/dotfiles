# Shared live ripgrep helpers for fzf (sourced by config/shell/s and rg-fzf-reload.zsh).

_fzf_rg_bin() {
  local candidate=""

  if [[ -n "${_FZF_RG_BIN:-}" && -x "${_FZF_RG_BIN}" ]]; then
    print -r -- "$_FZF_RG_BIN"
    return 0
  fi

  candidate="$(command -v rg 2>/dev/null)" || true
  if [[ -n "$candidate" && -x "$candidate" ]]; then
    typeset -g _FZF_RG_BIN="$candidate"
    print -r -- "$_FZF_RG_BIN"
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    candidate="$(brew --prefix 2>/dev/null)/bin/rg"
    if [[ -x "$candidate" ]]; then
      typeset -g _FZF_RG_BIN="$candidate"
      print -r -- "$_FZF_RG_BIN"
      return 0
    fi
  fi

  for candidate in /opt/homebrew/bin/rg /usr/local/bin/rg; do
    if [[ -x "$candidate" ]]; then
      typeset -g _FZF_RG_BIN="$candidate"
      print -r -- "$_FZF_RG_BIN"
      return 0
    fi
  done

  return 1
}

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

  local rg_bin=""
  rg_bin="$(_fzf_rg_bin)" || return 1

  (
    cd "${target_abs}" || exit 0
    export RIPGREP_CONFIG_PATH="${RIPGREP_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME}/.config/ripgrep/ripgreprc}"
    local -a rg_argv
    rg_argv=("${(@Q)${(z)query}}")
    (( ${#rg_argv[@]} )) || return 0
    "$rg_bin" "${rg_argv[@]}" --line-number --no-heading --color=never -- .
  ) | _fzf_rg_emit_relative_lines
}
