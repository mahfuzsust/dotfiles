#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
SOURCE_KEYMAP="$DOTFILES_DIR/config/idea/keymaps/Dotfiles.xml"

find_idea_config_dir() {
  local support="$HOME/Library/Application Support/JetBrains"
  [[ -d "$support" ]] || return 1
  ls -d "$support"/IntelliJIdea* 2>/dev/null | sort -V | tail -1
}

merge_dotfiles_keymap_into() {
  local target_keymap="$1"

  /usr/bin/python3 - "$SOURCE_KEYMAP" "$target_keymap" <<'PY'
import copy
import sys
import xml.etree.ElementTree as ET

source_path, target_path = sys.argv[1:3]
source_root = ET.parse(source_path).getroot()
tree = ET.parse(target_path)
root = tree.getroot()

for src_action in source_root.findall("action"):
    action_id = src_action.get("id")
    if not action_id:
        continue
    for action in root.findall("action"):
        if action.get("id") == action_id:
            root.remove(action)
    root.append(copy.deepcopy(src_action))

if hasattr(ET, "indent"):
    ET.indent(tree, space="  ")

# Move Caret to Code Block Start/End must not keep active ⌘⌥[ / ⌘⌥] (conflicts with bookmarks).
STRIP_MOVE_CARET_FROM = frozenset({"EditorCodeBlockStart", "EditorCodeBlockEnd"})
for action in root.findall("action"):
    if action.get("id") not in STRIP_MOVE_CARET_FROM:
        continue
    for ks in list(action.findall("keyboard-shortcut")):
        if ks.get("removed") == "true":
            continue
        action.remove(ks)

tree.write(target_path, encoding="unicode", xml_declaration=False)
PY
}

main() {
  local idea_dir="" keymaps_dir="" keymap_manager="" active="" target_keymap=""

  if [[ ! -f "$SOURCE_KEYMAP" ]]; then
    echo "idea-keymap: missing $SOURCE_KEYMAP" >&2
    exit 1
  fi

  idea_dir="$(find_idea_config_dir)" || exit 0

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
    merge_dotfiles_keymap_into "$target_keymap"
  elif [[ "$active" == "Dotfiles" ]]; then
    merge_dotfiles_keymap_into "$keymaps_dir/Dotfiles.xml"
    cat >"$keymap_manager" <<'EOF'
<application>
  <component name="KeymapManager">
    <active_keymap name="Dotfiles" />
  </component>
</application>
EOF
  fi
}

main "$@"
