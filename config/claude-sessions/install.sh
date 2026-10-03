#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/steveinflow/claude-sessions.git"
REPO_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/claude-sessions"
SCRIPT="$REPO_DIR/claude-sessions"
BIN="$HOME/.local/bin/claude-sessions"

mkdir -p "$HOME/.local/bin"

if [[ -f "$SCRIPT" ]]; then
  chmod +x "$SCRIPT"
  ln -sfn "$SCRIPT" "$BIN"
  echo "claude-sessions already installed: $BIN"
  exit 0
fi

if [[ -d "$REPO_DIR/.git" ]]; then
  echo "claude-sessions: repo at $REPO_DIR but script missing; updating…" >&2
  git -C "$REPO_DIR" pull --ff-only 2>/dev/null || true
else
  git clone --depth=1 "$REPO_URL" "$REPO_DIR"
fi

if [[ ! -f "$SCRIPT" ]]; then
  echo "claude-sessions: expected script at $SCRIPT" >&2
  exit 1
fi

chmod +x "$SCRIPT"
ln -sfn "$SCRIPT" "$BIN"
echo "Installed: $BIN"
