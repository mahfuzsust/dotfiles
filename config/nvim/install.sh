#!/usr/bin/env zsh
set -e

NVIM_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
LAZYVIM_STARTER="https://github.com/LazyVim/starter"

if ! command -v nvim >/dev/null 2>&1; then
    echo "nvim: not installed; skipping LazyVim starter (install neovim via Brewfile)"
    exit 0
fi

if [[ -f "$NVIM_DIR/init.lua" ]]; then
    echo "nvim: config already present at $NVIM_DIR"
    exit 0
fi

if [[ -e "$NVIM_DIR" ]]; then
    echo "nvim: $NVIM_DIR exists but is not a LazyVim starter (no init.lua); not overwriting" >&2
    exit 1
fi

echo "nvim: installing LazyVim starter..."
git clone "$LAZYVIM_STARTER" "$NVIM_DIR"
rm -rf "$NVIM_DIR/.git"
echo "nvim: LazyVim starter installed at $NVIM_DIR"
