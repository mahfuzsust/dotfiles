#!/usr/bin/env zsh
set -e # Exit on error

# 1. Determine absolute path of dotfiles directory
DOTFILES_DIR="${0:A:h}"
CONFIG_DIR="$HOME/.config"

# Function libraries (install/lib/*.sh)
for _lib in ui ssh configure zsh; do
    source "$DOTFILES_DIR/install/lib/${_lib}.sh"
done
unset _lib

echo "Starting dotfiles installation..."

USER_CONFIG="$DOTFILES_DIR/user-config.yml"
SSH_KEY="$HOME/.ssh/id_ed25519"
# shellcheck source=config/load-user-config.zsh
source "$DOTFILES_DIR/config/load-user-config.zsh"
ensure_user_config "$USER_CONFIG"
load_user_config "$USER_CONFIG"
apply_git_user_from_config
write_github_env "$CONFIG_DIR/dotfiles/github.env"
apply_github_from_config
load_notes_dir_from_config "$USER_CONFIG"
write_notes_env "$CONFIG_DIR/dotfiles/notes.env"
echo "Git user: $USER_NAME <$USER_EMAIL>"
echo "GitHub user: $GITHUB_USERNAME"
echo "Notes dir: $NOTES_DIR"

# 2. Install Homebrew if it isn't installed
if ! command -v brew &> /dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Load brew into current shell session for the rest of the script
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew is already installed."
fi

ensure_ssh_key
ensure_ssh_config

if ssh_key_loaded; then
    echo "SSH key already loaded in agent"
else
    echo "Add ssh-add"
    if [[ -e /dev/tty ]]; then
        ssh-add --apple-use-keychain "$SSH_KEY" </dev/tty >/dev/tty 2>/dev/null \
            || ssh-add "$SSH_KEY" </dev/tty >/dev/tty 2>/dev/null \
            || true
    else
        ssh-add --apple-use-keychain "$SSH_KEY" 2>/dev/null || ssh-add "$SSH_KEY" 2>/dev/null || true
    fi
fi

dotinstall_spin "Updating Homebrew…" brew update

if [[ -n "$(brew outdated 2>/dev/null)" ]]; then
    dotinstall_spin "Upgrading Homebrew packages…" brew upgrade
else
    echo "Homebrew packages already up to date"
fi

if brew cleanup -n 2>/dev/null | grep -q 'Would remove'; then
    dotinstall_spin "Cleaning Homebrew cache…" brew cleanup
else
    echo "Nothing to brew cleanup"
fi

# 3. Install packages via Brewfile (no brew update — it fails when global git
# config rewrites GitHub HTTPS to SSH and the SSH agent has no keys after restart)
if brew bundle check --file="$DOTFILES_DIR/Brewfile" >/dev/null 2>&1; then
    echo "Brewfile packages already installed"
elif ! dotinstall_spin "Installing Brewfile packages…" brew bundle --file="$DOTFILES_DIR/Brewfile"; then
    echo "brew bundle had failures; continuing with symlinks and shell setup" >&2
fi

dotinstall_load_gum_env

chmod +x "$DOTFILES_DIR/config/nvim/install.sh"
if ! dotinstall_spin "Setting up Neovim (LazyVim)…" "$DOTFILES_DIR/config/nvim/install.sh"; then
    echo "LazyVim starter install had failures; continuing" >&2
fi

chmod +x "$DOTFILES_DIR/config/fonts/install-fira-code-nerd-font-mono.sh"
if ! dotinstall_spin "Installing Fira Code Nerd Font…" "$DOTFILES_DIR/config/fonts/install-fira-code-nerd-font-mono.sh"; then
    echo "Fira Code Nerd Font Mono install had failures; continuing" >&2
fi

# go-task and taskwarrior both ship a "task" binary. Neither is linked by
# brew bundle (link: false in Brewfile); expose go-task as "task" and
# taskwarrior as "tk" via symlinks to avoid brew link conflicts.
brew unlink go-task >/dev/null 2>&1 || true
brew unlink task >/dev/null 2>&1 || true
brew_prefix="$(brew --prefix)"
go_task_bin="$(brew --prefix go-task)/bin/task"
taskwarrior_bin="$(brew --prefix task)/bin/task"
if [[ -x "$go_task_bin" ]] && [[ ! ( -e "$brew_prefix/bin/task" && "${brew_prefix}/bin/task:A" == "${go_task_bin:A}" ) ]]; then
    ln -sfn "$go_task_bin" "$brew_prefix/bin/task"
fi
if [[ -x "$taskwarrior_bin" ]] && [[ ! ( -e "$brew_prefix/bin/tk" && "${brew_prefix}/bin/tk:A" == "${taskwarrior_bin:A}" ) ]]; then
    ln -sfn "$taskwarrior_bin" "$brew_prefix/bin/tk"
fi

chmod +x "$DOTFILES_DIR/config/taskwarrior-obsidian/install.sh"
if ! dotinstall_spin "Installing taskwarrior-obsidian…" "$DOTFILES_DIR/config/taskwarrior-obsidian/install.sh"; then
    echo "taskwarrior-obsidian install had failures; continuing" >&2
fi

chmod +x "$DOTFILES_DIR/config/claude-sessions/install.sh"
if ! dotinstall_spin "Installing claude-sessions…" "$DOTFILES_DIR/config/claude-sessions/install.sh"; then
    echo "claude-sessions install had failures; continuing" >&2
fi

dotinstall_spin "Applying dotfiles configuration…" dotinstall_apply_configuration

# GPG commit signing (setup-gpg skips when signing key is already configured)
dotinstall_spin "Setting up GPG commit signing…" "$DOTFILES_DIR/config/git/setup-gpg"

dotinstall_spin "Setting up git delta pager…" "$DOTFILES_DIR/config/git/setup-delta"

# Configure Zsh plugins and FZF
SHELL_RC="$HOME/.zshrc"

dotinstall_spin "Configuring Zsh plugins…" dotinstall_finalize_zsh

if [[ -f "$SHELL_RC" ]]; then
    ensure_managed_zshrc "$SHELL_RC"
    ensure_dotfiles_zshenv
    ensure_dotfiles_zprofile
    normalize_zprofile

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

if [[ -n "${DOTFILES_INSTALL_FROM_DOTINSTALL:-}" ]]; then
    :
elif [[ -n "$ZSH_VERSION" && "$ZSH_EVAL_CONTEXT" == *:file* ]]; then
    reload_shell_config
    echo "Shell configuration reloaded"
else
    echo "Run: source ~/.zshrc"
fi
