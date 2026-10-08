#!/usr/bin/env zsh
# Go tools installed with mise-managed `go` (binaries land in ~/go/bin).
set -e

emulate -L zsh

install_dlv() {
  if ! command -v mise >/dev/null 2>&1; then
    echo "go/install: mise not found; skipping dlv" >&2
    return 0
  fi

  if ! mise exec -- go version >/dev/null 2>&1; then
    echo "go/install: go not available via mise; skipping dlv" >&2
    return 0
  fi

  echo "go/install: go install github.com/go-delve/delve/cmd/dlv@latest"
  mise exec -- go install github.com/go-delve/delve/cmd/dlv@latest
}

install_dlv
