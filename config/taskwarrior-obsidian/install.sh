#!/usr/bin/env zsh
set -e

REPO="mahfuzsust/taskwarrior-obsidian"
BIN="$HOME/.local/bin/taskwarrior-obsidian"
CONFIG_DIR="$HOME/.config/taskwarrior-obsidian"
CONFIG_FILE="$CONFIG_DIR/config.toml"
HOOKS_DIR="$HOME/.task/hooks"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/taskwarrior-obsidian"
REPO_TMPDIR=""
REPO_ROOT=""

taskwarrior_obsidian_hooks_present() {
  local -a hooks=( ${HOOKS_DIR}/*.taskwarrior-obsidian(N) )
  (( ${#hooks[@]} > 0 ))
}

taskwarrior_obsidian_arch() {
  local arch=""
  case "$(uname -s)" in
    Darwin)
      case "$(uname -m)" in
        arm64) arch="darwin-arm64" ;;
        x86_64) arch="darwin-amd64" ;;
        *)
          echo "taskwarrior-obsidian: unsupported macOS architecture: $(uname -m)" >&2
          return 1
          ;;
      esac
      ;;
    Linux)
      case "$(uname -m)" in
        x86_64) arch="linux-amd64" ;;
        aarch64 | arm64) arch="linux-arm64" ;;
        *)
          echo "taskwarrior-obsidian: unsupported Linux architecture: $(uname -m)" >&2
          return 1
          ;;
      esac
      ;;
    *)
      echo "taskwarrior-obsidian: unsupported OS: $(uname -s)" >&2
      return 1
      ;;
  esac
  print -r -- "$arch"
}

fetch_taskwarrior_obsidian_repo() {
  [[ -n "$REPO_ROOT" ]] && return 0

  command -v gh >/dev/null 2>&1 || {
    echo "taskwarrior-obsidian: gh CLI is required to download from repo" >&2
    return 1
  }

  REPO_TMPDIR="$(mktemp -d)"
  gh api "repos/${REPO}/tarball/main" > "$REPO_TMPDIR/repo.tar.gz"
  tar -xzf "$REPO_TMPDIR/repo.tar.gz" -C "$REPO_TMPDIR"
  REPO_ROOT="$(find "$REPO_TMPDIR" -maxdepth 1 -type d -name 'mahfuzsust-taskwarrior-obsidian-*' | head -1)"

  [[ -n "$REPO_ROOT" ]] || {
    echo "taskwarrior-obsidian: failed to extract repo" >&2
    return 1
  }
}

cleanup_taskwarrior_obsidian_repo() {
  [[ -n "$REPO_TMPDIR" ]] && rm -rf "$REPO_TMPDIR"
}

install_taskwarrior_obsidian_binary_from_archive() {
  local archive="$1" arch="$2" tmpdir="" extracted=""

  tmpdir="$(mktemp -d)"
  tar -xzf "$archive" -C "$tmpdir"
  extracted="$tmpdir/taskwarrior-obsidian-${arch}"

  [[ -f "$extracted" ]] || {
    echo "taskwarrior-obsidian: expected binary not found in release archive" >&2
    rm -rf "$tmpdir"
    return 1
  }

  mkdir -p "$HOME/.local/bin"
  install -m 755 "$extracted" "$BIN"
  rm -rf "$tmpdir"
  echo "Installed: $BIN"
}

install_taskwarrior_obsidian_binary() {
  local arch="" asset="" cached="" tmpdir=""

  if [[ -x "$BIN" ]]; then
    echo "taskwarrior-obsidian already installed: $BIN"
    return 0
  fi

  if [[ -f "$BIN" ]]; then
    chmod +x "$BIN"
    echo "taskwarrior-obsidian already installed: $BIN"
    return 0
  fi

  arch="$(taskwarrior_obsidian_arch)" || return 1
  asset="taskwarrior-obsidian-${arch}.tar.gz"
  cached="$CACHE_DIR/$asset"
  mkdir -p "$CACHE_DIR"

  if [[ -f "$cached" ]]; then
    echo "Using cached taskwarrior-obsidian (${arch})"
    install_taskwarrior_obsidian_binary_from_archive "$cached" "$arch"
    return 0
  fi

  command -v gh >/dev/null 2>&1 || {
    echo "taskwarrior-obsidian: gh CLI is required to download releases" >&2
    return 1
  }

  tmpdir="$(mktemp -d)"
  echo "Downloading taskwarrior-obsidian (${arch})..."
  gh release download --repo "$REPO" --pattern "$asset" --dir "$tmpdir"
  cp "$tmpdir/$asset" "$cached"
  install_taskwarrior_obsidian_binary_from_archive "$cached" "$arch"
  rm -rf "$tmpdir"
}

install_taskwarrior_obsidian_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    echo "Config already exists: $CONFIG_FILE"
    return 0
  fi

  fetch_taskwarrior_obsidian_repo || return 1

  [[ -f "$REPO_ROOT/config.example.toml" ]] || {
    echo "taskwarrior-obsidian: config.example.toml not found in repo" >&2
    return 1
  }

  mkdir -p "$CONFIG_DIR"
  cp "$REPO_ROOT/config.example.toml" "$CONFIG_FILE"
  echo "Created config: $CONFIG_FILE"
  echo "Edit vault path and directories before running taskwarrior-obsidian check"
}

install_taskwarrior_obsidian_hooks() {
  local hook=""

  if taskwarrior_obsidian_hooks_present; then
    echo "taskwarrior-obsidian hooks already installed in $HOOKS_DIR"
    return 0
  fi

  fetch_taskwarrior_obsidian_repo || return 1

  [[ -d "$REPO_ROOT/hooks" ]] || {
    echo "taskwarrior-obsidian: hooks directory not found in repo" >&2
    return 1
  }

  mkdir -p "$HOOKS_DIR"
  for hook in "$REPO_ROOT/hooks"/*.taskwarrior-obsidian(N); do
    install -m 755 "$hook" "$HOOKS_DIR/${hook:t}"
    echo "Installed hook: $HOOKS_DIR/${hook:t}"
  done
}

if [[ -x "$BIN" && -f "$CONFIG_FILE" ]] && taskwarrior_obsidian_hooks_present; then
  echo "taskwarrior-obsidian already fully installed"
else
  install_taskwarrior_obsidian_binary
  install_taskwarrior_obsidian_config
  install_taskwarrior_obsidian_hooks
  cleanup_taskwarrior_obsidian_repo
fi

if [[ -x "$BIN" ]]; then
  "$BIN" check 2>/dev/null && echo "taskwarrior-obsidian check passed" \
    || echo "Run 'taskwarrior-obsidian check' after editing $CONFIG_FILE"
fi
