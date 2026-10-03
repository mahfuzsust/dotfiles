# Symlinking, macOS defaults, and the main config-apply step. Sourced by install.sh (zsh).

# 4. Helper function for symlinking
link_file() {
    local src=$1
    local dest=$2

    mkdir -p "$(dirname "$dest")"

    if [[ -e "$dest" ]] && [[ "${dest:A}" == "${src:A}" ]]; then
        return 0
    fi

    ln -sfn "$src" "$dest"
}

defaults_write_if_needed() {
    local domain="$1" key="$2" expected="$3" current=""

    current="$(defaults read "$domain" "$key" 2>/dev/null || true)"
    if [[ "$current" == "$expected" ]]; then
        return 0
    fi
    defaults write "$domain" "$key" "$expected"
}

dotinstall_apply_configuration() {
    emulate -L zsh

# Link tool configurations
link_file "$DOTFILES_DIR/config/ripgrep/ripgreprc" "$CONFIG_DIR/ripgrep/ripgreprc"
link_file "$DOTFILES_DIR/config/fzf/fzf.env" "$CONFIG_DIR/fzf/fzf.env"
link_file "$DOTFILES_DIR/config/fzf/rg-fzf-lib.zsh" "$CONFIG_DIR/fzf/rg-fzf-lib.zsh"
link_file "$DOTFILES_DIR/config/fzf/rg-fzf-reload.zsh" "$CONFIG_DIR/fzf/rg-fzf-reload.zsh"
chmod +x "$CONFIG_DIR/fzf/rg-fzf-reload.zsh"
mkdir -p "$CONFIG_DIR/sdkman"
link_file "$DOTFILES_DIR/config/sdkman/packages" "$CONFIG_DIR/sdkman/packages"
mkdir -p "$CONFIG_DIR/zsh"
for zsh_file in "$DOTFILES_DIR/config/zsh"/*(N); do
    link_file "$zsh_file" "$CONFIG_DIR/zsh/${zsh_file:t}"
done
link_file "$DOTFILES_DIR/config/tmux/tmux.conf" "$HOME/.tmux.conf"
link_file "$DOTFILES_DIR/config/tmux/tmux.conf" "$CONFIG_DIR/tmux/tmux.conf"
link_file "$DOTFILES_DIR/config/tmux/status-right.sh" "$CONFIG_DIR/tmux/status-right.sh"
chmod +x "$CONFIG_DIR/tmux/status-right.sh"
if command -v tmux &>/dev/null && tmux info &>/dev/null; then
    tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
    echo "Reloaded tmux config"
fi

# --- THE IGNORE FILE WIRING ---

# 1. For Git (requires git config --global core.excludesfile)
link_file "$DOTFILES_DIR/ignore" "$HOME/.global_ignore"
git_config_set_if_needed core.excludesfile "$HOME/.global_ignore"

# Repo-local pre-commit hook (.githooks/pre-commit runs scripts/check.sh)
if [[ "$(git -C "$DOTFILES_DIR" config --get core.hooksPath 2>/dev/null)" != ".githooks" ]]; then
    git -C "$DOTFILES_DIR" config core.hooksPath .githooks
fi
git_config_set_if_needed init.defaultBranch main
git_config_set_if_needed rerere.enabled true

if command -v nvim >/dev/null 2>&1; then
    git_config_set_if_needed sequence.editor "nvim"
    git_config_set_if_needed core.editor "nvim"
fi

if command -v gh &>/dev/null; then
    if gh extension list 2>/dev/null | grep -q 'gh-stack'; then
        echo "gh-stack extension is already installed."
    else
        if dotinstall_spin "Installing gh-stack extension…" gh extension install github/gh-stack; then
            echo "gh-stack extension installed."
        else
            echo "Failed to install gh-stack extension (try: gh auth login)" >&2
        fi
    fi
else
    echo "gh CLI not found; skipping gh-stack extension install"
fi

# 2. For standalone fd (Native XDG path)
link_file "$DOTFILES_DIR/ignore" "$CONFIG_DIR/fd/ignore"

# 3. For standalone ripgrep (Native home dir path)
link_file "$DOTFILES_DIR/ignore" "$HOME/.ignore"


# --- iTerm2 Configuration ---

ITERM_PROFILE_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
ITERM_THEME_URL="https://raw.githubusercontent.com/mbadolato/iTerm2-Color-Schemes/master/schemes/Catppuccin%20Mocha.itermcolors"
ITERM_THEME="$CONFIG_DIR/iterm2/Catppuccin Mocha.itermcolors"
ITERM_PROFILE_BASE="$DOTFILES_DIR/config/iterm2/profile.base.json"
ITERM_PROFILE_OUT="$ITERM_PROFILE_DIR/profile.json"

mkdir -p "$CONFIG_DIR/iterm2"
mkdir -p "$ITERM_PROFILE_DIR"

link_file "$DOTFILES_DIR/config/iterm2/tmux-start.zsh" "$CONFIG_DIR/iterm2/tmux-start.zsh"
chmod +x "$CONFIG_DIR/iterm2/tmux-start.zsh"
chmod +x "$DOTFILES_DIR/config/iterm2/build-profile.py"

if [[ -f "$ITERM_THEME" ]]; then
    echo "iTerm2 theme already present: $ITERM_THEME"
else
    dotinstall_spin "Downloading iTerm2 Catppuccin theme…" \
        curl -fsSL "$ITERM_THEME_URL" -o "$ITERM_THEME"
fi

if [[ -L "$ITERM_PROFILE_OUT" ]]; then
    rm -f "$ITERM_PROFILE_OUT"
fi

if [[ -f "$ITERM_PROFILE_OUT" ]] \
    && [[ "$ITERM_PROFILE_OUT" -nt "$ITERM_PROFILE_BASE" ]] \
    && [[ "$ITERM_PROFILE_OUT" -nt "$ITERM_THEME" ]]; then
    echo "iTerm2 profile already built: $ITERM_PROFILE_OUT"
else
    dotinstall_spin "Building iTerm2 profile…" \
        python3 "$DOTFILES_DIR/config/iterm2/build-profile.py" \
        "$ITERM_PROFILE_BASE" \
        "$ITERM_THEME" \
        "$ITERM_PROFILE_OUT"
    echo "Built iTerm2 profile from Catppuccin Mocha theme"
fi

rm -f "$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch/set-default-profile.py" 2>/dev/null || true

# Disable the "Quit iTerm2?" prompt
defaults_write_if_needed com.googlecode.iterm2 PromptOnQuit 0

# Force iTerm2's window chrome to Dark Theme (0 = Light, 1 = Dark, 2 = Minimal)
defaults_write_if_needed com.googlecode.iterm2 TabStyleWithAutomaticOption 1

# --- macOS Terminal.app (github-dark) ---

chmod +x "$DOTFILES_DIR/config/terminal/install.sh"
if ! dotinstall_spin "Configuring Terminal.app…" "$DOTFILES_DIR/config/terminal/install.sh"; then
    echo "Terminal.app profile import had failures; see manual.md" >&2
fi

# --- VS Code / Cursor (shared settings) ---

VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"

mkdir -p "$VSCODE_USER_DIR" "$CURSOR_USER_DIR"
link_file "$DOTFILES_DIR/config/editor/settings.json" "$VSCODE_USER_DIR/settings.json"
link_file "$DOTFILES_DIR/config/editor/settings.json" "$CURSOR_USER_DIR/settings.json"
link_file "$DOTFILES_DIR/config/editor/keybindings.json" "$VSCODE_USER_DIR/keybindings.json"
link_file "$DOTFILES_DIR/config/editor/keybindings.json" "$CURSOR_USER_DIR/keybindings.json"

chmod +x "$DOTFILES_DIR/config/editor/install-catppuccin.sh"
dotinstall_spin "Installing editor Catppuccin themes…" "$DOTFILES_DIR/config/editor/install-catppuccin.sh"

chmod +x "$DOTFILES_DIR/config/idea/install-keymap.sh"
if ! dotinstall_spin "Installing IntelliJ keymap…" "$DOTFILES_DIR/config/idea/install-keymap.sh"; then
    echo "IntelliJ keymap install had failures; continuing" >&2
fi

# 1. Link shell config into ~/.config/shell
mkdir -p "$CONFIG_DIR/shell"
for shell_file in "$DOTFILES_DIR/config/shell"/*(N); do
    link_file "$shell_file" "$CONFIG_DIR/shell/${shell_file:t}"
done
link_file "$DOTFILES_DIR/config/git/gac" "$CONFIG_DIR/git/gac"
link_file "$DOTFILES_DIR/config/git/gpr" "$CONFIG_DIR/git/gpr"
link_file "$DOTFILES_DIR/config/git/gclean" "$CONFIG_DIR/git/gclean"
link_file "$DOTFILES_DIR/config/git/greview" "$CONFIG_DIR/git/greview"
link_file "$DOTFILES_DIR/config/git/setup-gpg" "$CONFIG_DIR/git/setup-gpg"
link_file "$DOTFILES_DIR/config/git/setup-delta" "$CONFIG_DIR/git/setup-delta"
rm -f "$CONFIG_DIR/git/gpgcopy" "$CONFIG_DIR/git/git_aliases" 2>/dev/null || true
rm -f "$CONFIG_DIR/git/preview" 2>/dev/null || true
chmod +x "$CONFIG_DIR/git/gac" "$CONFIG_DIR/git/gpr" "$CONFIG_DIR/git/gclean" "$CONFIG_DIR/git/greview" "$CONFIG_DIR/git/setup-gpg" "$CONFIG_DIR/git/setup-delta"

git config --global --unset include.path 2>/dev/null || true
}
