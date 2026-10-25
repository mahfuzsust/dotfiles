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
mkdir -p "$CONFIG_DIR/mise"
link_file "$DOTFILES_DIR/config/mise/config.toml" "$CONFIG_DIR/mise/config.toml"
write_claude_settings \
    "$DOTFILES_DIR/config/claude/settings.json" \
    "$HOME/.claude/settings.json" \
    "${USER_CONFIG:-$DOTFILES_DIR/user-config.yml}"
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
