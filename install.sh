#!/usr/bin/env zsh
set -e # Exit on error

# 1. Determine absolute path of dotfiles directory
DOTFILES_DIR="${0:A:h}"
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
git config --global rerere.enabled true

if command -v gh &>/dev/null; then
    if gh extension list 2>/dev/null | grep -q 'gh-stack'; then
        echo "✅ gh-stack extension is already installed."
    else
        echo "📦 Installing gh extension: gh-stack..."
        if gh extension install github/gh-stack; then
            echo "✅ gh-stack extension installed."
        else
            echo "⚠️  Failed to install gh-stack extension (try: gh auth login)" >&2
        fi
    fi
else
    echo "⚠️  gh CLI not found; skipping gh-stack extension install"
fi

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

# 1. Link shell config into ~/.config/shell
mkdir -p "$CONFIG_DIR/shell"
for shell_file in "$DOTFILES_DIR/config/shell"/*(N); do
    link_file "$shell_file" "$CONFIG_DIR/shell/${shell_file:t}"
done
link_file "$DOTFILES_DIR/config/git/gac" "$CONFIG_DIR/git/gac"
link_file "$DOTFILES_DIR/config/git/gpr" "$CONFIG_DIR/git/gpr"
link_file "$DOTFILES_DIR/config/git/gclean" "$CONFIG_DIR/git/gclean"
link_file "$DOTFILES_DIR/config/git/setup-gpg" "$CONFIG_DIR/git/setup-gpg"
rm -f "$CONFIG_DIR/git/gpgcopy" "$CONFIG_DIR/git/git_aliases" 2>/dev/null || true
chmod +x "$CONFIG_DIR/git/gac" "$CONFIG_DIR/git/gpr" "$CONFIG_DIR/git/gclean" "$CONFIG_DIR/git/setup-gpg"

git config --global --unset include.path 2>/dev/null || true

# GPG commit signing (creates key if needed, exports public key)
echo "🔐 Setting up GPG commit signing..."
"$DOTFILES_DIR/config/git/setup-gpg"

install_oh_my_zsh() {
    local omz_dir="$HOME/.oh-my-zsh"

    if [[ -d "$omz_dir" ]]; then
        echo "✅ Oh My Zsh is already installed."
        return 0
    fi

    echo "📦 Installing Oh My Zsh..."
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
    echo "✅ Oh My Zsh installed."
}

install_zsh_autosuggestions() {
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

    if [[ -d "$plugin_dir" ]]; then
        echo "✅ zsh-autosuggestions is already installed."
        return 0
    fi

    echo "📦 Installing zsh-autosuggestions..."
    mkdir -p "$(dirname "$plugin_dir")"
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir"
    echo "✅ zsh-autosuggestions installed."
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
    echo "📝 Added zsh-autosuggestions to Oh My Zsh plugins in $shell_rc"
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
        echo "🧹 Removed duplicate GPG_TTY entries from $shell_rc"
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
        echo "📝 Ensured GPG_TTY in DOTFILES SETUP in $shell_rc"
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
        echo "🧹 Removed stale Homebrew zsh plugin sources from $shell_rc"
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

    (( removed )) && echo "🧹 Removed old zsh-syntax-highlighting block from $shell_rc"
}

ensure_syntax_highlighting_in_zshrc() {
    local shell_rc="$1"

    if ! command -v brew >/dev/null 2>&1; then
        echo "⚠️  Homebrew not found; skipping zsh-syntax-highlighting setup" >&2
        return 0
    fi

    if ! brew --prefix zsh-syntax-highlighting >/dev/null 2>&1; then
        echo "⚠️  zsh-syntax-highlighting is not installed; run dotinstall to install Brew packages" >&2
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
    echo "📝 Added zsh-syntax-highlighting to end of $shell_rc"
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
        echo "🧹 Removed duplicate ${block_name} block from $shell_rc"
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
        echo "🧹 Removed duplicate ${label} source lines from $shell_rc"
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
        echo "🧹 Removed duplicate compfix blocks from $shell_rc"
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
        echo "🧹 Collapsed extra blank lines in $shell_rc"
    fi
}

normalize_zshrc() {
    local shell_rc="$1"

    cleanup_duplicate_compfix_blocks "$shell_rc"
    remove_duplicate_dotfiles_blocks "$shell_rc" "DOTFILES SETUP" \
        "# --- DOTFILES SETUP ---" "# --- END DOTFILES SETUP ---"
    remove_duplicate_dotfiles_blocks "$shell_rc" "DOTFILES ALIASES" \
        "# --- DOTFILES ALIASES ---" "# --- END DOTFILES ALIASES ---"
    remove_duplicate_dotfiles_blocks "$shell_rc" "DOTFILES SYNTAX HIGHLIGHTING" \
        "# --- DOTFILES SYNTAX HIGHLIGHTING ---" "# --- END DOTFILES SYNTAX HIGHLIGHTING ---"
    remove_source_outside_dotfiles_block "$shell_rc" \
        "# --- DOTFILES SETUP ---" "# --- END DOTFILES SETUP ---" \
        "config/fzf/fzf.env" "fzf"
    remove_source_outside_dotfiles_block "$shell_rc" \
        "# --- DOTFILES ALIASES ---" "# --- END DOTFILES ALIASES ---" \
        "config/shell/aliases" "aliases"
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

    echo "📝 Added Oh My Zsh to $target_file"
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
        echo "📝 Created $shell_rc with Oh My Zsh"
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
        echo "🔒 Fixed zsh completion permissions on $BREW_SHARE"
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
        echo "📝 Added zsh-completions and compfix disable to $SHELL_RC"
    fi

    # FZF and remaining plugins (append to the end)
    if ! grep -q "DOTFILES SETUP" "$SHELL_RC" 2>/dev/null; then
        cat << 'EOF' >> "$SHELL_RC"

# --- DOTFILES SETUP ---
# DOTFILES GPG TTY
export GPG_TTY=$(tty)

# Source fzf configuration
source "$HOME/.config/fzf/fzf.env"
# --- END DOTFILES SETUP ---
EOF
        echo "📝 Added plugins and fzf env to $SHELL_RC"
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
        echo "📝 Added dotfiles shell aliases to $SHELL_RC"
    fi

    ensure_gpg_tty_in_zshrc "$SHELL_RC"
    normalize_zshrc "$SHELL_RC"
    ensure_syntax_highlighting_in_zshrc "$SHELL_RC"

    set +e
    source "$SHELL_RC" 2>/dev/null
    set -e
else
    echo "⚠️  $SHELL_RC not found. Are you using Zsh?"
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

echo "🎉 Installation complete!"

if [[ -n "${DOTFILES_INSTALL_FROM_DOTINSTALL:-}" ]]; then
    :
elif [[ -n "$ZSH_VERSION" && "$ZSH_EVAL_CONTEXT" == *:file* ]]; then
    reload_shell_config
    echo "✅ Shell configuration reloaded"
else
    echo "↪ Run: source ~/.zshrc"
fi
