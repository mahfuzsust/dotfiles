#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
SOURCE_KEYMAP="$DOTFILES_DIR/config/idea/keymaps/Dotfiles.xml"
ACTION_ID="Github.Pull.Request.Show.In.Toolwindow"
SHORTCUT='meta t'

find_idea_config_dir() {
  local support="$HOME/Library/Application Support/JetBrains"
  [[ -d "$support" ]] || return 1
  ls -d "$support"/IntelliJIdea* 2>/dev/null | sort -V | tail -1
}

apply_shortcut_to_keymap_file() {
  local keymap_file="$1"

  /usr/bin/python3 - "$keymap_file" "$ACTION_ID" "$SHORTCUT" <<'PY'
import sys
import xml.etree.ElementTree as ET

path, action_id, shortcut = sys.argv[1:4]
tree = ET.parse(path)
root = tree.getroot()

for action in root.findall("action"):
    if action.get("id") == action_id:
        root.remove(action)

action = ET.SubElement(root, "action", {"id": action_id})
ks = ET.SubElement(action, "keyboard-shortcut")
ks.set("first-keystroke", shortcut)

if hasattr(ET, "indent"):
    ET.indent(tree, space="  ")

tree.write(path, encoding="unicode", xml_declaration=False)
PY
}

main() {
  local idea_dir="" keymaps_dir="" keymap_manager="" active="" target_keymap=""

  if [[ ! -f "$SOURCE_KEYMAP" ]]; then
    echo "idea-keymap: missing $SOURCE_KEYMAP" >&2
    exit 1
  fi

  idea_dir="$(find_idea_config_dir)" || {
    echo "idea-keymap: IntelliJ IDEA config not found; open IDEA once, then re-run dotinstall"
    exit 0
  }

  keymaps_dir="$idea_dir/keymaps"
  keymap_manager="$idea_dir/options/mac/keymap.xml"
  mkdir -p "$keymaps_dir" "$(dirname "$keymap_manager")"

  cp "$SOURCE_KEYMAP" "$keymaps_dir/Dotfiles.xml"

  active="Dotfiles"
  if [[ -f "$keymap_manager" ]] && grep -q 'active_keymap name=' "$keymap_manager" 2>/dev/null; then
    active="$(sed -n 's/.*active_keymap name="\([^"]*\)".*/\1/p' "$keymap_manager" | head -1)"
    [[ -n "$active" ]] || active="Dotfiles"
  fi

  target_keymap="$keymaps_dir/${active}.xml"
  if [[ -f "$target_keymap" ]]; then
    apply_shortcut_to_keymap_file "$target_keymap"
    echo "idea-keymap: set Cmd+T on $ACTION_ID in keymap \"$active\""
  else
    if [[ "$active" != "Dotfiles" ]]; then
      echo "idea-keymap: active keymap \"$active\" has no file; also installed Dotfiles keymap"
      echo "idea-keymap: select Settings → Keymap → Dotfiles to use Cmd+T, or duplicate your keymap to keymaps/${active}.xml"
    else
      apply_shortcut_to_keymap_file "$keymaps_dir/Dotfiles.xml"
      cat >"$keymap_manager" <<'EOF'
<application>
  <component name="KeymapManager">
    <active_keymap name="Dotfiles" />
  </component>
</application>
EOF
      echo "idea-keymap: activated Dotfiles keymap with Cmd+T → Show Pull Request in Tool Window"
    fi
  fi
}

main "$@"
