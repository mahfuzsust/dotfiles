#!/usr/bin/env zsh
# Remove SDKMAN! and all candidates (~/.sdkman). Idempotent.
# https://sdkman.io/install/ (uninstall section)
emulate -L zsh

SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"

strip_sdkman_from_shell_file() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  grep -qE 'sdkman-init\.sh|SDKMAN_DIR' "$f" 2>/dev/null || return 0

  local tmp=""
  tmp="$(mktemp)"
  grep -vE 'sdkman-init\.sh|SDKMAN_DIR|THIS MUST BE AT THE END OF THE FILE FOR SDKMAN' "$f" >"$tmp" || true
  mv "$tmp" "$f"
  echo "remove-sdkman: stripped SDKMAN init from ${f}"
}

if [[ -d "$SDKMAN_DIR" ]]; then
  echo "remove-sdkman: deleting ${SDKMAN_DIR} (all installed candidates)"
  rm -rf "$SDKMAN_DIR"
else
  echo "remove-sdkman: ${SDKMAN_DIR} not present"
fi

for f in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; do
  strip_sdkman_from_shell_file "$f"
done

rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/sdkman/packages" \
  "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/sdkman.env" 2>/dev/null || true
rmdir "${XDG_CONFIG_HOME:-$HOME/.config}/sdkman" 2>/dev/null || true

echo "remove-sdkman: done"
