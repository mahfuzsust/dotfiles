#!/usr/bin/env zsh
set -e

SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
SDKMAN_INIT="$SDKMAN_DIR/bin/sdkman-init.sh"
SDKMAN_CONFIG="$SDKMAN_DIR/etc/config"
CONFIG_DIR="${1:-}"

if [[ -z "$CONFIG_DIR" || ! -d "$CONFIG_DIR" ]]; then
  echo "sdkman: expected config directory as first argument" >&2
  exit 1
fi

PACKAGES_FILE="$CONFIG_DIR/packages"

sdkman_config_set() {
  local key="$1" value="$2" cfg="$SDKMAN_CONFIG"
  [[ -f "$cfg" ]] || return 0
  if grep -q "^${key}=" "$cfg" 2>/dev/null; then
    if [[ "$(uname -s)" == Darwin ]]; then
      sed -i '' "s/^${key}=.*/${key}=${value}/" "$cfg"
    else
      sed -i "s/^${key}=.*/${key}=${value}/" "$cfg"
    fi
  else
    print -r -- "${key}=${value}" >>"$cfg"
  fi
}

# CI installer sets aggressive curl limits; sbt/Java downloads need longer (or no cap).
sdkman_tune_config() {
  sdkman_config_set sdkman_auto_answer true
  sdkman_config_set sdkman_curl_connect_timeout 30
  sdkman_config_set sdkman_curl_max_time 0
  sdkman_config_set sdkman_healthcheck_enable false
}

ensure_sdkman() {
  if [[ -s "$SDKMAN_INIT" ]]; then
    echo "SDKMAN! already installed: $SDKMAN_DIR"
    sdkman_tune_config
    return 0
  fi

  command -v curl >/dev/null 2>&1 || {
    echo "sdkman: curl is required (install via Homebrew or macOS CLI tools)" >&2
    return 1
  }

  echo "Installing SDKMAN! (https://sdkman.io/install/)…"
  curl -fsSL "https://get.sdkman.io?rcupdate=false&ci=true" | zsh
  [[ -s "$SDKMAN_INIT" ]] || {
    echo "sdkman: install finished but $SDKMAN_INIT is missing" >&2
    return 1
  }
  sdkman_tune_config
}

load_sdkman() {
  # shellcheck source=/dev/null
  source "$SDKMAN_INIT"
}

run_packages() {
  local line="" failures=0 ret=0

  [[ -f "$PACKAGES_FILE" ]] || {
    echo "sdkman: missing $PACKAGES_FILE" >&2
    return 1
  }

  set +e
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue

    if [[ "$line" != sdk\ * ]]; then
      echo "sdkman: skip (lines must start with 'sdk '): $line" >&2
      continue
    fi

    echo "sdkman: $line"
    $=line
    ret=$?
    if (( ret != 0 )); then
      echo "sdkman: command failed (exit $ret): $line" >&2
      (( failures++ ))
    fi
  done <"$PACKAGES_FILE"
  set -e

  if (( failures > 0 )); then
    echo "sdkman: $failures package command(s) failed" >&2
    return 1
  fi
}

ensure_sdkman
load_sdkman
run_packages
