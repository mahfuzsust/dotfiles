#!/usr/bin/env bash
set -euo pipefail

CATPPUCCIN_EXT="Catppuccin.catppuccin-vsc"

install_catppuccin() {
  local cli=$1

  if ! command -v "$cli" >/dev/null 2>&1; then
    echo "⚠️  $cli not found; skipping Catppuccin theme install"
    return 0
  fi

  echo "⬇️  Installing Catppuccin theme for $cli..."
  if "$cli" --install-extension "$CATPPUCCIN_EXT" --force; then
    echo "✅ Catppuccin theme installed for $cli"
  else
    echo "⚠️  Failed to install Catppuccin theme for $cli" >&2
  fi
}

install_catppuccin code
install_catppuccin cursor
