#!/usr/bin/env zsh
set -e # Exit on error

# 1. Determine absolute path of dotfiles directory
DOTFILES_DIR="${0:A:h}"
CONFIG_DIR="$HOME/.config"

echo "Starting dotfiles installation..."

USER_CONFIG="$DOTFILES_DIR/user-config.yml"
SSH_KEY="$HOME/.ssh/id_ed25519"
# shellcheck source=config/load-user-config.zsh
source "$DOTFILES_DIR/config/load-user-config.zsh"
load_user_config "$USER_CONFIG"
apply_git_user_from_config
write_github_env "$CONFIG_DIR/dotfiles/github.env"
apply_github_from_config
echo "Git user: $USER_NAME <$USER_EMAIL>"
echo "GitHub user: $GITHUB_USERNAME"

# 2. Install Homebrew if it isn't installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Load brew into current shell session for the rest of the script
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew is already installed."
fi

ensure_ssh_key() {
    if [[ -f "$SSH_KEY" ]]; then
        return 0
    fi

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    echo "No SSH key at $SSH_KEY."
    echo "Running: ssh-keygen -t ed25519 -C \"$USER_EMAIL\""
    echo "Use the prompts (default path is fine; passphrase is optional)."

    if [[ ! -e /dev/tty ]]; then
        echo "No TTY for interactive ssh-keygen; run manually:" >&2
        echo "  ssh-keygen -t ed25519 -C \"$USER_EMAIL\"" >&2
        exit 1
    fi

    if ! ssh-keygen -t ed25519 -C "$USER_EMAIL" </dev/tty >/dev/tty; then
        echo "ssh-keygen failed or was cancelled" >&2
        exit 1
    fi

    if [[ ! -f "$SSH_KEY" ]]; then
        echo "Expected key at $SSH_KEY after ssh-keygen" >&2
        exit 1
    fi

    echo "SSH public key (copy: pbcopy < ${SSH_KEY}.pub):"
    cat "${SSH_KEY}.pub"
    if pbcopy < "${SSH_KEY}.pub" 2>/dev/null; then
        echo "Public key copied to clipboard — paste at https://github.com/settings/ssh/new"
    fi
}

ensure_ssh_config() {
    local ssh_config="$HOME/.ssh/config"
    local marker_begin="# --- DOTFILES SSH (macOS keychain) ---"
    local marker_end="# --- END DOTFILES SSH ---"

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [[ -f "$ssh_config" ]] && grep -Fq "$marker_begin" "$ssh_config" 2>/dev/null; then
        echo "SSH config already contains dotfiles keychain block"
        return 0
    fi

    if [[ -f "$ssh_config" ]] && grep -Fq 'UseKeychain yes' "$ssh_config" 2>/dev/null \
        && grep -Fq 'IdentityFile ~/.ssh/id_ed25519' "$ssh_config" 2>/dev/null; then
        echo "SSH config already configures id_ed25519 with keychain"
        return 0
    fi

    {
        if [[ -f "$ssh_config" ]] && [[ -s "$ssh_config" ]]; then
            print -r -- ""
        fi
        cat <<'EOF'
# --- DOTFILES SSH (macOS keychain) ---
Host *
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile ~/.ssh/id_ed25519
# --- END DOTFILES SSH ---
EOF
    } >>"$ssh_config"

    chmod 600 "$ssh_config"
    echo "Appended macOS keychain SSH settings to $ssh_config"
}

ensure_ssh_key
ensure_ssh_config

echo "Add ssh-add"
if [[ -e /dev/tty ]]; then
    ssh-add --apple-use-keychain "$SSH_KEY" </dev/tty >/dev/tty 2>/dev/null \
        || ssh-add "$SSH_KEY" </dev/tty >/dev/tty 2>/dev/null \
        || true
else
    ssh-add --apple-use-keychain "$SSH_KEY" 2>/dev/null || ssh-add "$SSH_KEY" 2>/dev/null || true
fi

echo "Running Brew update"
brew update

echo "Running Brew upgrade"
brew upgrade

echo "Running Brew cleanup"
brew cleanup

# 3. Install packages via Brewfile (no brew update — it fails when global git
# config rewrites GitHub HTTPS to SSH and the SSH agent has no keys after restart)
echo "Installing/upgrading Brewfile packages..."
if ! brew bundle --file="$DOTFILES_DIR/Brewfile"; then
    echo "brew bundle had failures; continuing with symlinks and shell setup" >&2
fi

# go-task and taskwarrior both ship a "task" binary. Neither is linked by
# brew bundle (link: false in Brewfile); expose go-task as "task" and
# taskwarrior as "tk" via symlinks to avoid brew link conflicts.
brew unlink go-task >/dev/null 2>&1 || true
brew unlink task >/dev/null 2>&1 || true
brew_prefix="$(brew --prefix)"
go_task_bin="$(brew --prefix go-task)/bin/task"
taskwarrior_bin="$(brew --prefix task)/bin/task"
if [[ -x "$go_task_bin" ]]; then
    ln -sfn "$go_task_bin" "$brew_prefix/bin/task"
fi
if [[ -x "$taskwarrior_bin" ]]; then
    ln -sfn "$taskwarrior_bin" "$brew_prefix/bin/tk"
fi

echo "Installing taskwarrior-obsidian..."
chmod +x "$DOTFILES_DIR/config/taskwarrior-obsidian/install.sh"
if ! "$DOTFILES_DIR/config/taskwarrior-obsidian/install.sh"; then
    echo "taskwarrior-obsidian install had failures; continuing" >&2
fi

# 4. Helper function for symlinking
link_file() {
    local src=$1
    local dest=$2

    # Create destination directory if it doesn't exist
    mkdir -p "$(dirname "$dest")"

    # -s: symbolic, -f: force (overwrite existing), -n: treat dest as normal file if it's a symlink to a dir
    ln -sfn "$src" "$dest"
}

echo "Setting up symlinks..."

# Link tool configurations
link_file "$DOTFILES_DIR/config/ripgrep/ripgreprc" "$CONFIG_DIR/ripgrep/ripgreprc"
link_file "$DOTFILES_DIR/config/fzf/fzf.env" "$CONFIG_DIR/fzf/fzf.env"
link_file "$DOTFILES_DIR/config/tmux/tmux.conf" "$HOME/.tmux.conf"
link_file "$DOTFILES_DIR/config/tmux/tmux.conf" "$CONFIG_DIR/tmux/tmux.conf"
link_file "$DOTFILES_DIR/config/tmux/status-right.sh" "$CONFIG_DIR/tmux/status-right.sh"
chmod +x "$CONFIG_DIR/tmux/status-right.sh"
if command -v tmux &>/dev/null; then
    tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
    echo "Reloaded tmux config"
fi

# --- THE IGNORE FILE WIRING ---

# 1. For Git (requires git config --global core.excludesfile)
link_file "$DOTFILES_DIR/ignore" "$HOME/.global_ignore"
git config --global core.excludesfile "$HOME/.global_ignore"
git config --global init.defaultBranch main
git config --global rerere.enabled true

if command -v gh &>/dev/null; then
    if gh extension list 2>/dev/null | grep -q 'gh-stack'; then
        echo "gh-stack extension is already installed."
    else
        echo "Installing gh extension: gh-stack..."
        if gh extension install github/gh-stack; then
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

echo "Configuring iTerm2..."

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

echo "Downloading Catppuccin Mocha iTerm2 theme..."
curl -fsSL "$ITERM_THEME_URL" -o "$ITERM_THEME"

# Remove stale symlink from older installs (profile is generated here, not in dotfiles)
rm -f "$ITERM_PROFILE_OUT"

python3 "$DOTFILES_DIR/config/iterm2/build-profile.py" \
    "$ITERM_PROFILE_BASE" \
    "$ITERM_THEME" \
    "$ITERM_PROFILE_OUT"
echo "Built iTerm2 profile from Catppuccin Mocha theme"

rm -f "$HOME/Library/Application Support/iTerm2/Scripts/AutoLaunch/set-default-profile.py" 2>/dev/null || true

# Disable the "Quit iTerm2?" prompt
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

# Force iTerm2's window chrome to Dark Theme (0 = Light, 1 = Dark, 2 = Minimal)
defaults write com.googlecode.iterm2 TabStyleWithAutomaticOption -int 1

# --- macOS Terminal.app (Chalice Dark) ---

echo "Configuring Terminal.app..."
chmod +x "$DOTFILES_DIR/config/terminal/install.sh"
if ! "$DOTFILES_DIR/config/terminal/install.sh"; then
    echo "Terminal.app profile import had failures; see config/manual.md" >&2
fi

# --- VS Code / Cursor (shared settings) ---

VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"

mkdir -p "$VSCODE_USER_DIR" "$CURSOR_USER_DIR"
link_file "$DOTFILES_DIR/config/editor/settings.json" "$VSCODE_USER_DIR/settings.json"
link_file "$DOTFILES_DIR/config/editor/settings.json" "$CURSOR_USER_DIR/settings.json"

chmod +x "$DOTFILES_DIR/config/editor/install-catppuccin.sh"
"$DOTFILES_DIR/config/editor/install-catppuccin.sh"

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
rm -f "$CONFIG_DIR/git/gpgcopy" "$CONFIG_DIR/git/git_aliases" 2>/dev/null || true
rm -f "$CONFIG_DIR/git/preview" 2>/dev/null || true
chmod +x "$CONFIG_DIR/git/gac" "$CONFIG_DIR/git/gpr" "$CONFIG_DIR/git/gclean" "$CONFIG_DIR/git/greview" "$CONFIG_DIR/git/setup-gpg"

git config --global --unset include.path 2>/dev/null || true

# GPG commit signing (creates key if needed, exports public key)
echo "Setting up GPG commit signing..."
"$DOTFILES_DIR/config/git/setup-gpg"

install_oh_my_zsh() {
    local omz_dir="$HOME/.oh-my-zsh"

    if [[ -d "$omz_dir" ]]; then
        echo "Oh My Zsh is already installed."
        return 0
    fi

    echo "Installing Oh My Zsh..."
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
    echo "Oh My Zsh installed."
}

install_zsh_autosuggestions() {
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

    if [[ -d "$plugin_dir" ]]; then
        echo "zsh-autosuggestions is already installed."
        return 0
    fi

    echo "Installing zsh-autosuggestions..."
    mkdir -p "$(dirname "$plugin_dir")"
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir"
    echo "zsh-autosuggestions installed."
}

ensure_zsh_autosuggestions_plugin() {
    local shell_rc="$1"

    if grep -q 'zsh-autosuggestions' "$shell_rc" 2>/dev/null; then
        return 0
    fi

    if ! grep -q '^plugins=(' "$shell_rc" 2>/dev/null; then
        return 0
    fi

    local temp_rc=""
    temp_rc="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == plugins=* ]] && [[ "$line" != *zsh-autosuggestions* ]]; then
            line="${line%)} zsh-autosuggestions)"
        fi
        print -r -- "$line"
    done <"$shell_rc" >"$temp_rc"
    mv "$temp_rc" "$shell_rc"
    echo "Added zsh-autosuggestions to Oh My Zsh plugins in $shell_rc"
}

cleanup_gpg_tty_in_zshrc() {
    local shell_rc="$1"
    local temp_rc="" removed=0 keep_next_export=0

    [[ -f "$shell_rc" ]] || return 0

    temp_rc="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == *'GPG_TTY=$(tty)'*'>> ~/.zshrc'* ]] \
            || [[ "$line" == *'GPG_TTY=$(tty)'*'>> ~/.zprofile'* ]]; then
            removed=1
            continue
        fi

        if [[ "$line" == "# DOTFILES GPG TTY" ]]; then
            keep_next_export=1
            print -r -- "$line"
            continue
        fi

        if (( keep_next_export )) && [[ "$line" == 'export GPG_TTY=$(tty)' ]]; then
            keep_next_export=0
            print -r -- "$line"
            continue
        fi

        if [[ "$line" == 'export GPG_TTY=$(tty)' ]]; then
            removed=1
            continue
        fi

        print -r -- "$line"
    done <"$shell_rc" >"$temp_rc"
    mv "$temp_rc" "$shell_rc"

    if (( removed )); then
        echo "Removed duplicate GPG_TTY entries from $shell_rc"
    fi
}

ensure_local_bin_in_zshrc() {
    local shell_rc="$1"

    if grep -q 'DOTFILES LOCAL BIN' "$shell_rc" 2>/dev/null \
        && grep -q '\$HOME/.local/bin' "$shell_rc" 2>/dev/null; then
        return 0
    fi

    if ! grep -q "DOTFILES SETUP" "$shell_rc" 2>/dev/null; then
        return 0
    fi

    local temp_rc="" added=0
    temp_rc="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        print -r -- "$line"
        if [[ "$line" == "export GPG_TTY=\$(tty)" ]] && (( ! added )) \
            && ! grep -q 'DOTFILES LOCAL BIN' "$shell_rc" 2>/dev/null; then
            print -r -- ""
            print -r -- "# DOTFILES LOCAL BIN"
            print -r -- 'export PATH="$HOME/.local/bin:$PATH"'
            added=1
        fi
    done <"$shell_rc" >"$temp_rc"
    mv "$temp_rc" "$shell_rc"

    if (( added )); then
        echo "Ensured ~/.local/bin in PATH in $shell_rc"
    fi
}

ensure_gpg_tty_in_zshrc() {
    local shell_rc="$1"

    if grep -q 'DOTFILES GPG TTY' "$shell_rc" 2>/dev/null \
        && grep -A1 '# DOTFILES GPG TTY' "$shell_rc" 2>/dev/null | grep -Fq 'export GPG_TTY=$(tty)'; then
        return 0
    fi

    if ! grep -q "DOTFILES SETUP" "$shell_rc" 2>/dev/null; then
        return 0
    fi

    local temp_rc="" added=0
    temp_rc="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        print -r -- "$line"
        if [[ "$line" == "# --- DOTFILES SETUP ---" ]] && (( ! added )) \
            && ! grep -q 'DOTFILES GPG TTY' "$shell_rc" 2>/dev/null; then
            print -r -- "# DOTFILES GPG TTY"
            print -r -- "export GPG_TTY=\$(tty)"
            print -r -- ""
            added=1
        elif [[ "$line" == "# DOTFILES GPG TTY" ]] && (( ! added )); then
            print -r -- "export GPG_TTY=\$(tty)"
            added=1
        fi
    done <"$shell_rc" >"$temp_rc"
    mv "$temp_rc" "$shell_rc"

    if (( added )); then
        echo "Ensured GPG_TTY in DOTFILES SETUP in $shell_rc"
    fi
}

cleanup_stale_brew_zsh_plugins_in_zshrc() {
    local shell_rc="$1"
    local temp_rc="" removed=0 skip_brew_block=0 in_syntax_block=0 depth=0

    [[ -f "$shell_rc" ]] || return 0

    temp_rc="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "# --- DOTFILES SYNTAX HIGHLIGHTING ---" ]]; then
            in_syntax_block=1
            print -r -- "$line"
            continue
        fi
        if [[ "$line" == "# --- END DOTFILES SYNTAX HIGHLIGHTING ---" ]]; then
            in_syntax_block=0
            print -r -- "$line"
            continue
        fi
        if (( in_syntax_block )); then
            print -r -- "$line"
            continue
        fi

        if [[ "$line" == "# Source Homebrew Zsh plugins" ]]; then
            skip_brew_block=1
            depth=0
            removed=1
            continue
        fi

        if (( skip_brew_block )); then
            if [[ "$line" =~ '^[[:space:]]*if ' ]]; then
                (( depth++ ))
            elif [[ "$line" == "fi" ]] || [[ "$line" =~ '^[[:space:]]*fi[[:space:]]*$' ]]; then
                (( depth-- ))
                if (( depth <= 0 )); then
                    skip_brew_block=0
                fi
            fi
            continue
        fi

        if [[ "$line" == "# Autosuggestions" ]] \
            || [[ "$line" == "# Syntax Highlighting (Must be sourced LAST)" ]] \
            || [[ "$line" == *'zsh-autosuggestions/zsh-autosuggestions.zsh'* ]] \
            || [[ "$line" == *'zsh-syntax-highlighting/zsh-syntax-highlighting.zsh'* ]]; then
            removed=1
            continue
        fi

        print -r -- "$line"
    done <"$shell_rc" >"$temp_rc"
    mv "$temp_rc" "$shell_rc"

    if (( removed )); then
        echo "Removed stale Homebrew zsh plugin sources from $shell_rc"
    fi
}

remove_dotfiles_syntax_highlighting_block() {
    local shell_rc="$1"
    local temp_rc="" removed=0 skipping=0

    [[ -f "$shell_rc" ]] || return 0

    temp_rc="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "# --- DOTFILES SYNTAX HIGHLIGHTING ---" ]]; then
            skipping=1
            removed=1
            continue
        fi
        if (( skipping )); then
            [[ "$line" == "# --- END DOTFILES SYNTAX HIGHLIGHTING ---" ]] && skipping=0
            continue
        fi
        print -r -- "$line"
    done <"$shell_rc" >"$temp_rc"
    mv "$temp_rc" "$shell_rc"

    (( removed )) && echo "Removed old zsh-syntax-highlighting block from $shell_rc"
}

ensure_syntax_highlighting_in_zshrc() {
    local shell_rc="$1"

    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew not found; skipping zsh-syntax-highlighting setup" >&2
        return 0
    fi

    if ! brew --prefix zsh-syntax-highlighting >/dev/null 2>&1; then
        echo "zsh-syntax-highlighting is not installed; run dotinstall to install Brew packages" >&2
        return 0
    fi

    if grep -q "DOTFILES SYNTAX HIGHLIGHTING" "$shell_rc" 2>/dev/null; then
        if grep -q 'zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' "$shell_rc" 2>/dev/null; then
            return 0
        fi
        remove_dotfiles_syntax_highlighting_block "$shell_rc"
    elif grep -q 'zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' "$shell_rc" 2>/dev/null; then
        cleanup_stale_brew_zsh_plugins_in_zshrc "$shell_rc"
    fi

    cat << 'EOF' >> "$shell_rc"

# --- DOTFILES SYNTAX HIGHLIGHTING ---
# Must be sourced last: https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md
if type brew &>/dev/null; then
  BREW_PREFIX=$(brew --prefix)
  if [ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi
fi
# --- END DOTFILES SYNTAX HIGHLIGHTING ---
EOF
    echo "Added zsh-syntax-highlighting to end of $shell_rc"
}

ensure_kubectl_completion_in_zshrc() {
    local shell_rc="$1"
    local block=""
    local temp_rc=""

    if grep -q "DOTFILES KUBECTL COMPLETION" "$shell_rc" 2>/dev/null \
        && grep -q 'kubectl completion zsh' "$shell_rc" 2>/dev/null; then
        return 0
    fi

    block="$(cat <<'EOF'

# --- DOTFILES KUBECTL COMPLETION ---
source <(kubectl completion zsh)
# --- END DOTFILES KUBECTL COMPLETION ---
EOF
)"

    if grep -q "# --- DOTFILES SYNTAX HIGHLIGHTING ---" "$shell_rc" 2>/dev/null; then
        temp_rc="$(mktemp)"
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "# --- DOTFILES SYNTAX HIGHLIGHTING ---" ]]; then
                print -r -- "$block"
            fi
            print -r -- "$line"
        done <"$shell_rc" >"$temp_rc"
        mv "$temp_rc" "$shell_rc"
    else
        print -r -- "$block" >>"$shell_rc"
    fi

    echo "Added kubectl completion to $shell_rc"
}

remove_duplicate_dotfiles_blocks() {
    local shell_rc="$1"
    local block_name="$2"
    local start_marker="$3"
    local end_marker="$4"
    local temp_rc="" skipping=0 seen=0 removed=0

    [[ -f "$shell_rc" ]] || return 0

    temp_rc="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "$start_marker" ]]; then
            if (( seen )); then
                skipping=1
                removed=1
                continue
            fi
            seen=1
            print -r -- "$line"
            continue
        fi

        if (( skipping )) && [[ "$line" == "$end_marker" ]]; then
            skipping=0
            continue
        fi

        if (( skipping )); then
            continue
        fi

        print -r -- "$line"
    done <"$shell_rc" >"$temp_rc"
    mv "$temp_rc" "$shell_rc"

    if (( removed )); then
        echo "Removed duplicate ${block_name} block from $shell_rc"
    fi
}

remove_source_outside_dotfiles_block() {
    local shell_rc="$1"
    local block_start="$2"
    local block_end="$3"
    local source_pattern="$4"
    local label="$5"
    local temp_rc="" in_block=0 removed=0

    [[ -f "$shell_rc" ]] || return 0
    grep -q "$block_start" "$shell_rc" 2>/dev/null || return 0
    grep -q "$source_pattern" "$shell_rc" 2>/dev/null || return 0

    temp_rc="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "$block_start" ]]; then
            in_block=1
            print -r -- "$line"
            continue
        fi
        if [[ "$line" == "$block_end" ]]; then
            in_block=0
            print -r -- "$line"
            continue
        fi
        if (( in_block )); then
            print -r -- "$line"
            continue
        fi
        if [[ "$line" == *"$source_pattern"* ]]; then
            removed=1
            continue
        fi
        if [[ "$line" == "# Source fzf configuration" ]] && [[ "$label" == "fzf" ]]; then
            removed=1
            continue
        fi
        if [[ "$line" == "# Source dotfiles shell aliases" ]]; then
            removed=1
            continue
        fi
        print -r -- "$line"
    done <"$shell_rc" >"$temp_rc"
    mv "$temp_rc" "$shell_rc"

    if (( removed )); then
        echo "Removed duplicate ${label} source lines from $shell_rc"
    fi
}

cleanup_duplicate_compfix_blocks() {
    local shell_rc="$1"
    local temp_rc="" removed=0 skip=0 depth=0 has_compfix=0

    [[ -f "$shell_rc" ]] || return 0
    grep -q 'ZSH_DISABLE_COMPFIX' "$shell_rc" 2>/dev/null || return 0

    temp_rc="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "# Setup Homebrew zsh-completions" ]] && (( has_compfix )); then
            skip=1
            depth=0
            removed=1
            continue
        fi

        if [[ "$line" == *ZSH_DISABLE_COMPFIX* ]]; then
            has_compfix=1
        fi

        if (( skip )); then
            if [[ "$line" =~ '^[[:space:]]*if ' ]]; then
                (( depth++ ))
            elif [[ "$line" == "fi" ]] || [[ "$line" =~ '^[[:space:]]*fi[[:space:]]*$' ]]; then
                (( depth-- ))
                if (( depth <= 0 )); then
                    skip=0
                fi
            fi
            continue
        fi

        print -r -- "$line"
    done <"$shell_rc" >"$temp_rc"
    mv "$temp_rc" "$shell_rc"

    if (( removed )); then
        echo "Removed duplicate compfix blocks from $shell_rc"
    fi
}

collapse_empty_lines_in_zshrc() {
    local shell_rc="$1"
    local prev_empty=0 removed=0 line="" lines=()

    [[ -f "$shell_rc" ]] || return 0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "${line//[[:space:]]/}" ]]; then
            if (( prev_empty )); then
                removed=1
                continue
            fi
            prev_empty=1
        else
            prev_empty=0
        fi
        lines+=("$line")
    done <"$shell_rc"

    while (( ${#lines[@]} > 0 )) && [[ -z "${lines[$#lines]//[[:space:]]/}" ]]; do
        unset "lines[$#lines]"
        removed=1
    done

    : >"$shell_rc"
    for line in "${lines[@]}"; do
        print -r -- "$line" >>"$shell_rc"
    done

    if (( removed )); then
        echo "Collapsed extra blank lines in $shell_rc"
    fi
}

normalize_zshrc() {
    local shell_rc="$1"

    cleanup_duplicate_compfix_blocks "$shell_rc"
    remove_duplicate_dotfiles_blocks "$shell_rc" "DOTFILES SETUP" \
        "# --- DOTFILES SETUP ---" "# --- END DOTFILES SETUP ---"
    remove_duplicate_dotfiles_blocks "$shell_rc" "DOTFILES ALIASES" \
        "# --- DOTFILES ALIASES ---" "# --- END DOTFILES ALIASES ---"
    remove_duplicate_dotfiles_blocks "$shell_rc" "DOTFILES KUBECTL COMPLETION" \
        "# --- DOTFILES KUBECTL COMPLETION ---" "# --- END DOTFILES KUBECTL COMPLETION ---"
    remove_duplicate_dotfiles_blocks "$shell_rc" "DOTFILES SYNTAX HIGHLIGHTING" \
        "# --- DOTFILES SYNTAX HIGHLIGHTING ---" "# --- END DOTFILES SYNTAX HIGHLIGHTING ---"
    remove_source_outside_dotfiles_block "$shell_rc" \
        "# --- DOTFILES SETUP ---" "# --- END DOTFILES SETUP ---" \
        "config/fzf/fzf.env" "fzf"
    remove_source_outside_dotfiles_block "$shell_rc" \
        "# --- DOTFILES ALIASES ---" "# --- END DOTFILES ALIASES ---" \
        "config/shell/aliases" "aliases"
    remove_source_outside_dotfiles_block "$shell_rc" \
        "# --- DOTFILES KUBECTL COMPLETION ---" "# --- END DOTFILES KUBECTL COMPLETION ---" \
        "kubectl completion zsh" "kubectl completion"
    cleanup_stale_brew_zsh_plugins_in_zshrc "$shell_rc"
    cleanup_gpg_tty_in_zshrc "$shell_rc"
    collapse_empty_lines_in_zshrc "$shell_rc"
}

insert_oh_my_zsh_block() {
    local target_file="$1"
    local omz_block="$2"

    if grep -q 'oh-my-zsh\.sh' "$target_file" 2>/dev/null; then
        return 0
    fi

    if grep -q "ZSH_DISABLE_COMPFIX" "$target_file" 2>/dev/null; then
        local temp_rc="" line="" in_compfix=0 inserted=0
        temp_rc="$(mktemp)"
        while IFS= read -r line || [[ -n "$line" ]]; do
            print -r -- "$line" >>"$temp_rc"
            if [[ "$line" == *ZSH_DISABLE_COMPFIX* ]]; then
                in_compfix=1
            elif (( in_compfix )) && [[ "$line" == "fi" ]] && (( ! inserted )); then
                print -r -- "$omz_block" >>"$temp_rc"
                inserted=1
                in_compfix=0
            fi
        done <"$target_file"
        mv "$temp_rc" "$target_file"
    else
        local temp_rc=""
        temp_rc="$(mktemp)"
        print -r -- "$omz_block" >"$temp_rc"
        cat "$target_file" >>"$temp_rc"
        mv "$temp_rc" "$target_file"
    fi

    echo "Added Oh My Zsh to $target_file"
}

ensure_oh_my_zsh_in_zshrc() {
    local shell_rc="$1"
    local omz_block=""

    omz_block="$(cat <<'EOF'
# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions)

source "$ZSH/oh-my-zsh.sh"

EOF
)"

    if [[ ! -f "$shell_rc" ]]; then
        print -r -- "$omz_block" >"$shell_rc"
        echo "Created $shell_rc with Oh My Zsh"
        return 0
    fi

    insert_oh_my_zsh_block "$shell_rc" "$omz_block"
}

# Configure Zsh plugins and FZF
SHELL_RC="$HOME/.zshrc"

install_oh_my_zsh
install_zsh_autosuggestions
ensure_oh_my_zsh_in_zshrc "$SHELL_RC"
ensure_zsh_autosuggestions_plugin "$SHELL_RC"

# Homebrew's share dir is group-writable by default, which triggers the compinit
# "Ignore insecure directories" prompt on every new shell.
if command -v brew &>/dev/null; then
    BREW_SHARE="$(brew --prefix)/share"
    if [ -d "$BREW_SHARE" ]; then
        chmod go-w "$BREW_SHARE"
        echo "Fixed zsh completion permissions on $BREW_SHARE"
    fi
fi

if [[ -f "$SHELL_RC" ]]; then
    # zsh-completions + compfix disable (must be before OMZ/compinit)
    if ! grep -q "ZSH_DISABLE_COMPFIX" "$SHELL_RC" 2>/dev/null; then
        TEMP_RC="$(mktemp)"
        cat << 'EOF' > "$TEMP_RC"
# Setup Homebrew zsh-completions and fix insecure directory warnings
export ZSH_DISABLE_COMPFIX=true
if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh-completions:$FPATH"
fi

EOF
        cat "$SHELL_RC" >> "$TEMP_RC"
        mv "$TEMP_RC" "$SHELL_RC"
        echo "Added zsh-completions and compfix disable to $SHELL_RC"
    fi

    # FZF and remaining plugins (append to the end)
    if ! grep -q "DOTFILES SETUP" "$SHELL_RC" 2>/dev/null; then
        cat << 'EOF' >> "$SHELL_RC"

# --- DOTFILES SETUP ---
# DOTFILES GPG TTY
export GPG_TTY=$(tty)

# DOTFILES LOCAL BIN
export PATH="$HOME/.local/bin:$PATH"

# Source fzf configuration
source "$HOME/.config/fzf/fzf.env"
# --- END DOTFILES SETUP ---
EOF
        echo "Added plugins and fzf env to $SHELL_RC"
    fi

    # Shell aliases must load after Oh My Zsh (git plugin defines gpr = pull --rebase)
    if ! grep -q "DOTFILES ALIASES" "$SHELL_RC" 2>/dev/null; then
        cat << 'EOF' >> "$SHELL_RC"

# --- DOTFILES ALIASES ---
# Override Oh My Zsh git plugin aliases before loading dotfiles aliases
unalias gpr 2>/dev/null
unalias gprm 2>/dev/null
source "$HOME/.config/shell/aliases"
# --- END DOTFILES ALIASES ---
EOF
        echo "Added dotfiles shell aliases to $SHELL_RC"
    fi

    ensure_gpg_tty_in_zshrc "$SHELL_RC"
    ensure_local_bin_in_zshrc "$SHELL_RC"
    normalize_zshrc "$SHELL_RC"
    ensure_kubectl_completion_in_zshrc "$SHELL_RC"
    ensure_syntax_highlighting_in_zshrc "$SHELL_RC"

    set +e
    source "$SHELL_RC" 2>/dev/null
    set -e
else
    echo "$SHELL_RC not found. Are you using Zsh?"
fi

reload_shell_config() {
    set +e
    if [[ -f "$SHELL_RC" ]]; then
        source "$SHELL_RC" 2>/dev/null
    elif [[ -f "$CONFIG_DIR/shell/aliases" ]]; then
        source "$CONFIG_DIR/shell/aliases" 2>/dev/null
    fi
    set -e
}

echo "Installation complete!"
echo "Manual steps (SSH, gh auth, app logins): see $DOTFILES_DIR/config/manual.md"

if [[ -n "${DOTFILES_INSTALL_FROM_DOTINSTALL:-}" ]]; then
    :
elif [[ -n "$ZSH_VERSION" && "$ZSH_EVAL_CONTEXT" == *:file* ]]; then
    reload_shell_config
    echo "Shell configuration reloaded"
else
    echo "Run: source ~/.zshrc"
fi
