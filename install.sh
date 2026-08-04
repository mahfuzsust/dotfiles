#!/usr/bin/env zsh
set -e # Exit on error

# 1. Determine absolute path of dotfiles directory
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"

echo "🚀 Starting dotfiles installation..."

# 2. Install Homebrew if it isn't installed
if ! command -v brew &> /dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Load brew into current shell session for the rest of the script
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "✅ Homebrew is already installed."
fi

# 3. Install packages via Brewfile
echo "🍺 Bundling Homebrew packages..."
brew bundle --file="$DOTFILES_DIR/Brewfile"

# 4. Helper function for symlinking
link_file() {
    local src=$1
    local dest=$2

    # Create destination directory if it doesn't exist
    mkdir -p "$(dirname "$dest")"

    # -s: symbolic, -f: force (overwrite existing), -n: treat dest as normal file if it's a symlink to a dir
    ln -sfn "$src" "$dest"
    echo "🔗 Linked: $dest -> $src"
}

echo "📂 Setting up symlinks..."

# Link tool configurations
link_file "$DOTFILES_DIR/config/ripgrep/ripgreprc" "$CONFIG_DIR/ripgrep/ripgreprc"
link_file "$DOTFILES_DIR/config/fzf/fzf.env" "$CONFIG_DIR/fzf/fzf.env"

# --- THE IGNORE FILE WIRING ---

# 1. For Git (requires git config --global core.excludesfile)
link_file "$DOTFILES_DIR/ignore" "$HOME/.global_ignore"
git config --global core.excludesfile "$HOME/.global_ignore"
git config --global init.defaultBranch main

# 2. For standalone fd (Native XDG path)
link_file "$DOTFILES_DIR/ignore" "$CONFIG_DIR/fd/ignore"

# 3. For standalone ripgrep (Native home dir path)
link_file "$DOTFILES_DIR/ignore" "$HOME/.ignore"


# --- iTerm2 Configuration ---

echo "⚙️ Configuring iTerm2..."

# 1. Link the Dynamic Profile (Handles Font, Size, and Colors)
ITERM_PROFILE_DIR="$HOME/Library/Application Support/iTerm2/DynamicProfiles"
mkdir -p "$ITERM_PROFILE_DIR"
link_file "$DOTFILES_DIR/config/iterm2/profile.json" "$ITERM_PROFILE_DIR/profile.json"

# 2. Disable the "Quit iTerm2?" prompt
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

# 3. Force iTerm2's window chrome to Dark Theme
# 0 = Light, 1 = Dark, 2 = Minimal
defaults write com.googlecode.iterm2 TabStyleWithAutomaticOption -int 1

# 1. Link the alias files to your ~/.config directory
link_file "$DOTFILES_DIR/config/shell/aliases" "$CONFIG_DIR/shell/aliases"
link_file "$DOTFILES_DIR/config/git/git_aliases" "$CONFIG_DIR/git/git_aliases"
link_file "$DOTFILES_DIR/config/git/gac" "$CONFIG_DIR/git/gac"
chmod +x "$CONFIG_DIR/git/gac"

# 2. Tell Git to include your git_aliases file automatically
git config --global include.path "$CONFIG_DIR/git/git_aliases"

# Configure Zsh plugins and FZF
SHELL_RC="$HOME/.zshrc"

# Homebrew's share dir is group-writable by default, which triggers the compinit
# "Ignore insecure directories" prompt on every new shell.
if command -v brew &>/dev/null; then
    BREW_SHARE="$(brew --prefix)/share"
    if [ -d "$BREW_SHARE" ]; then
        chmod go-w "$BREW_SHARE"
        echo "🔒 Fixed zsh completion permissions on $BREW_SHARE"
    fi
fi

if [ -f "$SHELL_RC" ]; then
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
        echo "📝 Added zsh-completions and compfix disable to $SHELL_RC"
    fi

    # 2. FZF and remaining plugins (Append to the end)
    if ! grep -q "DOTFILES SETUP" "$SHELL_RC" 2>/dev/null; then
        cat << 'EOF' >> "$SHELL_RC"

# --- DOTFILES SETUP ---
# Source shell aliases
source "$HOME/.config/shell/aliases"

# Source fzf configuration
source "$HOME/.config/fzf/fzf.env"

# Source Homebrew Zsh plugins
if type brew &>/dev/null; then
  BREW_PREFIX=$(brew --prefix)

  # Autosuggestions
  if [ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  fi

  # Syntax Highlighting (Must be sourced LAST)
  if [ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi
fi
# --- END DOTFILES SETUP ---
EOF
        echo "📝 Added plugins and fzf env to $SHELL_RC"
    fi

    if ! grep -q 'config/shell/aliases' "$SHELL_RC" 2>/dev/null; then
        cat << 'EOF' >> "$SHELL_RC"

# Source dotfiles shell aliases
source "$HOME/.config/shell/aliases"
EOF
        echo "📝 Added shell aliases to $SHELL_RC"
    fi
else
    echo "⚠️  $SHELL_RC not found. Are you using Zsh?"
fi

source ~/.zshrc

echo "🎉 Installation complete!"
