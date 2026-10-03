#!/usr/bin/env zsh
set -e

REPO="mahfuzsust/taskwarrior-obsidian"
BIN="$HOME/.local/bin/taskwarrior-obsidian"
CONFIG_DIR="$HOME/.config/taskwarrior-obsidian"
CONFIG_FILE="$CONFIG_DIR/config.toml"
HOOKS_DIR="$HOME/.task/hooks"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/taskwarrior-obsidian"
REPO_CACHE="$CACHE_DIR/repo.tar.gz"
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

require_gh() {
  command -v gh >/dev/null 2>&1 || {
    echo "taskwarrior-obsidian: gh CLI is required" >&2
    return 1
  }
  if ! gh auth status >/dev/null 2>&1; then
    echo "taskwarrior-obsidian: gh not authenticated (run: gh auth login)" >&2
    return 1
  fi
}

run_with_timeout() {
  local secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    "$@"
  fi
}

fetch_taskwarrior_obsidian_repo() {
  [[ -n "$REPO_ROOT" ]] && return 0

  require_gh || return 1

  if [[ -f "$REPO_CACHE" ]]; then
    REPO_TMPDIR="$(mktemp -d)"
    cp "$REPO_CACHE" "$REPO_TMPDIR/repo.tar.gz"
  else
    REPO_TMPDIR="$(mktemp -d)"
    echo "taskwarrior-obsidian: fetching repo source (for config/hooks)…"
    if ! run_with_timeout 120 gh api "repos/${REPO}/tarball/main" > "$REPO_TMPDIR/repo.tar.gz"; then
      echo "taskwarrior-obsidian: failed to download repo tarball" >&2
      return 1
    fi
    mkdir -p "$CACHE_DIR"
    cp "$REPO_TMPDIR/repo.tar.gz" "$REPO_CACHE"
  fi

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

download_release_asset() {
  local asset="$1" dest="$2" asset_id="" token=""

  require_gh || return 1

  if ! run_with_timeout 30 gh api "repos/${REPO}/releases/latest" --jq .tag_name >/dev/null; then
    echo "taskwarrior-obsidian: no latest release or no access to ${REPO}" >&2
    echo "taskwarrior-obsidian: publish a release with asset ${asset}, or place the binary at ${BIN}" >&2
    return 1
  fi

  asset_id="$(run_with_timeout 30 gh api "repos/${REPO}/releases/latest" \
    --jq ".assets[] | select(.name==\"${asset}\") | .id" 2>/dev/null || true)"
  asset_id="${asset_id//[$'\t\r\n ']}"
  if [[ -z "$asset_id" ]]; then
    echo "taskwarrior-obsidian: release has no asset named ${asset}" >&2
    return 1
  fi

  token="$(gh auth token 2>/dev/null)" || {
    echo "taskwarrior-obsidian: could not read gh auth token" >&2
    return 1
  }

  echo "taskwarrior-obsidian: downloading ${asset}…"
  if ! run_with_timeout 600 curl -fsSL \
    --connect-timeout 30 \
    --max-time 600 \
    -H "Authorization: Bearer ${token}" \
    -H "Accept: application/octet-stream" \
    -L "https://api.github.com/repos/${REPO}/releases/assets/${asset_id}" \
    -o "$dest"; then
    echo "taskwarrior-obsidian: download failed or timed out" >&2
    rm -f "$dest"
    return 1
  fi

  [[ -s "$dest" ]] || {
    echo "taskwarrior-obsidian: download produced an empty file" >&2
    rm -f "$dest"
    return 1
  }
}

install_taskwarrior_obsidian_binary() {
  local arch="" asset="" cached=""

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

  download_release_asset "$asset" "$cached" || return 1
  install_taskwarrior_obsidian_binary_from_archive "$cached" "$arch"
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
  set +e
  install_taskwarrior_obsidian_binary
  binary_ret=$?
  set -e
  if (( binary_ret != 0 )); then
    echo "taskwarrior-obsidian: binary install skipped or failed; continuing with config/hooks" >&2
  fi
  install_taskwarrior_obsidian_config
  install_taskwarrior_obsidian_hooks
  cleanup_taskwarrior_obsidian_repo
fi

if [[ -x "$BIN" ]]; then
  "$BIN" check 2>/dev/null && echo "taskwarrior-obsidian check passed" \
    || echo "Run 'taskwarrior-obsidian check' after editing $CONFIG_FILE"
fi
