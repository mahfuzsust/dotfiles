#!/usr/bin/env bash
# fzf + read/select prompts for git helpers and install scripts.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  exit 0
fi

if declare -f pick_option >/dev/null 2>&1; then
  return 0
fi

_restore_tty() {
  stty sane 2>/dev/null || true
}

_fzf_pick_stdin() {
  local prompt="$1"
  fzf --prompt="${prompt} " --height=40% --border --reverse 2>/dev/null
}

# pick_option "Prompt" item1 item2 ...
pick_option() {
  local header="$1"
  shift
  local count=$# choice=""

  if (( count == 0 )); then
    return 1
  fi

  if command -v fzf >/dev/null 2>&1; then
    choice="$(printf '%s\n' "$@" | _fzf_pick_stdin "${header}")" || choice=""
    _restore_tty
    if [[ -n "$choice" ]]; then
      printf '%s' "$choice"
      return 0
    fi
  fi

  if [[ ! -e /dev/tty ]]; then
    echo "pick: no TTY (use fzf in a terminal)" >&2
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

# pick_stdin "Prompt"  (lines on stdin)
pick_stdin() {
  local header="$1"
  local choice="" items=""
  local -a arr=()

  items="$(cat)"
  [[ -n "$items" ]] || return 1

  if command -v fzf >/dev/null 2>&1; then
    choice="$(printf '%s\n' "$items" | _fzf_pick_stdin "${header}")" || choice=""
    _restore_tty
    if [[ -n "$choice" ]]; then
      printf '%s' "$choice"
      return 0
    fi
  fi

  while IFS= read -r line; do
    [[ -n "$line" ]] && arr+=("$line")
  done <<<"$items"
  (( ${#arr[@]} )) || return 1
  pick_option "$header" "${arr[@]}"
}

# prompt_input "Prompt" [default_value]
prompt_input() {
  local prompt="$1"
  local default="${2:-}"
  local value=""

  _restore_tty
  if [[ ! -e /dev/tty ]]; then
    echo "prompt: no TTY" >&2
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

# confirm_prompt "Message" — exit 0 if confirmed, 1 if not
confirm_prompt() {
  local message="$1"
  local reply=""

  if [[ ! -e /dev/tty ]]; then
    return 1
  fi
  read -r -p "${message} [y/N]: " reply </dev/tty
  case "$reply" in
    [yY] | [yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}
