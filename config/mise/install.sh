#!/usr/bin/env zsh
set -e

GLOBAL_CONFIG="${MISE_GLOBAL_CONFIG_FILE:-$HOME/.config/mise/config.toml}"

command -v mise >/dev/null 2>&1 || {
  echo "mise: not found (install via Brewfile: brew \"mise\")" >&2
  exit 1
}

[[ -f "$GLOBAL_CONFIG" ]] || {
  echo "mise: missing $GLOBAL_CONFIG (link config/mise/config.toml first)" >&2
  exit 1
}

mise trust "$GLOBAL_CONFIG" 2>/dev/null || true

if ! mise install; then
  echo "mise: install had failures" >&2
  exit 1
fi
