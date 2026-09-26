#!/usr/bin/env bash
set -euo pipefail

CATPPUCCIN_EXT="Catppuccin.catppuccin-vsc"
BOOKMARKS_EXT="alefragnani.Bookmarks"

install_extension() {
  local cli=$1
  local ext_id=$2
  local label=$3

  if ! command -v "$cli" >/dev/null 2>&1; then
    echo "$cli not found; skipping $label install"
    return 0
  fi

  if NODE_NO_WARNINGS=1 "$cli" --list-extensions 2>/dev/null | grep -Fi "$ext_id"; then
    echo "$label already installed for $cli"
    return 0
  fi

  echo "Installing $label for $cli..."
  if NODE_NO_WARNINGS=1 "$cli" --install-extension "$ext_id"; then
    echo "$label installed for $cli"
  else
    echo "Failed to install $label for $cli" >&2
  fi
}

install_extension code "$CATPPUCCIN_EXT" "Catppuccin theme"
install_extension cursor "$CATPPUCCIN_EXT" "Catppuccin theme"
install_extension code "$BOOKMARKS_EXT" "Bookmarks extension"
install_extension cursor "$BOOKMARKS_EXT" "Bookmarks extension"
