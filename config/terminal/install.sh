#!/usr/bin/env zsh
set -e

DOTFILES_DIR="${0:A:h:h:h}"
TERMINAL_THEME="$DOTFILES_DIR/config/terminal/Chalice Dark.terminal"
TERMINAL_PLIST="$HOME/Library/Preferences/com.apple.Terminal.plist"

if [[ ! -f "$TERMINAL_THEME" ]]; then
    echo "terminal: theme missing at $TERMINAL_THEME" >&2
    exit 1
fi

TERMINAL_PROFILE_NAME="$(/usr/libexec/PlistBuddy -c 'Print :name' "$TERMINAL_THEME")"

if [[ ! -f "$TERMINAL_PLIST" ]]; then
    /usr/bin/defaults read com.apple.Terminal >/dev/null 2>&1 || true
fi

if [[ ! -f "$TERMINAL_PLIST" ]]; then
    echo "terminal: open Terminal.app once, then re-run dotinstall" >&2
    exit 1
fi

/usr/libexec/PlistBuddy -c "Delete :'Window Settings':'${TERMINAL_PROFILE_NAME}'" "$TERMINAL_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :'Window Settings':'${TERMINAL_PROFILE_NAME}' dict" "$TERMINAL_PLIST"
/usr/libexec/PlistBuddy -c "Merge ${(q)TERMINAL_THEME} :'Window Settings':'${TERMINAL_PROFILE_NAME}'" "$TERMINAL_PLIST"

/usr/bin/defaults write com.apple.Terminal "Default Window Settings" "$TERMINAL_PROFILE_NAME"
/usr/bin/defaults write com.apple.Terminal "Startup Window Settings" "$TERMINAL_PROFILE_NAME"

echo "Terminal.app: imported \"$TERMINAL_PROFILE_NAME\" and set as default"
