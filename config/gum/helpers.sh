#!/usr/bin/env bash
# Shared helpers: fzf for lists (like before), gum for prompts/spin/confirm.
# https://github.com/charmbracelet/gum

if [[ -n "${DOTFILES_GUM_HELPERS_SOURCED:-}" ]]; then
  :
else
DOTFILES_GUM_HELPERS_SOURCED=1

_gum_available() {
  command -v gum >/dev/null 2>&1 && [[ -e /dev/tty ]]
}

_gum_restore_tty() {
  stty sane 2>/dev/null || true
}

_fzf_pick_stdin() {
  local prompt="$1"
  fzf --prompt="${prompt} " --height=40% --border --reverse 2>/dev/null
}

# pick_option "Prompt" item1 item2 ...  (fzf, then bash select)
gum_pick() {
  local header="$1"
  shift
  local count=$# choice=""

  if (( count == 0 )); then
    return 1
  fi

  if command -v fzf >/dev/null 2>&1; then
    choice="$(printf '%s\n' "$@" | _fzf_pick_stdin "${header} ")" || choice=""
    _gum_restore_tty
    if [[ -n "$choice" ]]; then
      printf '%s' "$choice"
      return 0
    fi
  fi

  if [[ ! -e /dev/tty ]]; then
    echo "pick: no TTY (use fzf in a terminal or run dotinstall)" >&2
    printf ''
    return 0
  fi

  echo "Select ${header}:" >&2
  PS3="${header}> "
  select choice in "$@"; do
    if [[ -n "${choice:-}" ]]; then
      break
    fi
    echo "Invalid selection, try again." >&2
  done
  printf '%s' "$choice"
}

# pick_stdin "Prompt"  (lines on stdin; fzf then select)
gum_pick_stdin() {
  local header="$1"
  local choice="" items=""
  local -a arr=()

  items="$(cat)"
  [[ -n "$items" ]] || return 1

  if command -v fzf >/dev/null 2>&1; then
    choice="$(printf '%s\n' "$items" | _fzf_pick_stdin "${header} ")" || choice=""
    _gum_restore_tty
    if [[ -n "$choice" ]]; then
      printf '%s' "$choice"
      return 0
    fi
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] && arr+=("$line")
  done <<<"$items"
  (( ${#arr[@]} )) || return 1
  gum_pick "$header" "${arr[@]}"
}

# gum_prompt_input "Prompt" [default_value]
gum_prompt_input() {
  local prompt="$1"
  local default="${2:-}"
  local value=""

  if _gum_available; then
    if [[ -n "$default" ]]; then
      value="$(gum input --prompt="${prompt} " --value "$default" 2>/dev/null)" || value=""
    else
      value="$(gum input --prompt="${prompt} " 2>/dev/null)" || value=""
    fi
    _gum_restore_tty
    if [[ -n "$value" ]]; then
      printf '%s' "$value"
      return 0
    fi
  fi

  _gum_restore_tty
  if [[ ! -e /dev/tty ]]; then
    echo "gum: no TTY for prompt" >&2
    printf ''
    return 0
  fi
  if [[ -n "$default" ]]; then
    read -e -r -p "${prompt} [${default}]: " value </dev/tty
    value="${value:-$default}"
  else
    read -e -r -p "${prompt}: " value </dev/tty
  fi
  printf '%s' "$value"
}

# gum_prompt_write "Header" [file_with_initial_content]
gum_prompt_write() {
  local header="$1"
  local initial="${2:-}"
  local body=""

  if _gum_available; then
    if [[ -n "$initial" && -f "$initial" ]]; then
      body="$(gum write --header="$header" --value "$(cat "$initial")" 2>/dev/null)" || body=""
    else
      body="$(gum write --header="$header" 2>/dev/null)" || body=""
    fi
    _gum_restore_tty
    if [[ -n "$body" ]]; then
      printf '%s' "$body"
      return 0
    fi
  fi

  return 1
}

# gum_confirm "Message" — exit 0 if confirmed, 1 if not
gum_confirm() {
  local message="$1"

  if _gum_available; then
    gum confirm "$message"
    local ret=$?
    _gum_restore_tty
    return "$ret"
  fi

  if [[ ! -e /dev/tty ]]; then
    return 1
  fi
  read -r -p "${message} [y/N]: " _gum_confirm_reply </dev/tty
  case "$_gum_confirm_reply" in
    [yY] | [yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# gum_spin "Title" command [args...]
gum_spin() {
  local title="$1"
  shift

  if _gum_available; then
    gum spin --spinner dot --title "$title" --show-output -- "$@"
    return $?
  fi

  "$@"
}

fi
