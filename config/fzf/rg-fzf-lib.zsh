# Shared live ripgrep helpers for fzf (sourced by config/shell/s and rg-fzf-reload.zsh).

_fzf_rg_config_path() {
  print -r -- "${RIPGREP_CONFIG_PATH:-${DOTFILES_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}}/ripgrep/ripgreprc}"
}

_fzf_rg_bin() {
  emulate -L zsh
  setopt localoptions no_aliases
  local candidate=""

  if [[ -n "${_FZF_RG_BIN:-}" && -x "${_FZF_RG_BIN}" ]]; then
    print -r -- "$_FZF_RG_BIN"
    return 0
  fi

  candidate="$(whence -p rg 2>/dev/null)" || true
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

# fzf reload-sync: {q} arrives as ONE quoted arg; the reloader word-splits it. noglob avoids expanding REA*.
_fzf_rg_reload_command() {
  local target_abs="$1"
  local reloader="${DOTFILES_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}}/fzf/rg-fzf-reload.zsh"

  _fzf_rg_bin >/dev/null || return 1
  [[ -f "$reloader" ]] || return 1

  print -rn -- "noglob zsh -f ${(q)reloader} ${(q)target_abs} {q} || true"
}

# True while rg would just error and blank the list (empty query, or a flag still waiting for its value).
_fzf_rg_query_incomplete() {
  (( $# )) || return 0
  case "${@[-1]}" in
    -g|--glob|-t|--type|-T|--type-not|-e|--regexp|-f|--file|-m|--max-count|-A|-B|-C|--iglob) return 0 ;;
  esac
  return 1
}
