# Oh My Zsh, plugins, ~/.zshenv, ~/.zprofile, and the managed ~/.zshrc. Sourced by install.sh (zsh).

install_oh_my_zsh() {
    local omz_dir="$HOME/.oh-my-zsh"

    if [[ -d "$omz_dir" ]]; then
        echo "Oh My Zsh is already installed."
        return 0
    fi

    dotinstall_spin "Installing Oh My Zsh…" \
        git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
    echo "Oh My Zsh installed."
}

install_zsh_autosuggestions() {
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"

    if [[ -d "$plugin_dir" ]]; then
        echo "zsh-autosuggestions is already installed."
        return 0
    fi

    mkdir -p "$(dirname "$plugin_dir")"
    dotinstall_spin "Installing zsh-autosuggestions…" \
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir"
    echo "zsh-autosuggestions installed."
}

install_fast_syntax_highlighting() {
    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/fast-syntax-highlighting"

    if [[ -d "$plugin_dir" ]]; then
        echo "fast-syntax-highlighting is already installed."
        return 0
    fi

    mkdir -p "$(dirname "$plugin_dir")"
    dotinstall_spin "Installing fast-syntax-highlighting…" \
        git clone --depth=1 https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$plugin_dir"
    echo "fast-syntax-highlighting installed."
}

ensure_dotfiles_zshenv() {
    local zshenv="$HOME/.zshenv"
    local block=""

    block="$(cat <<'EOF'
# --- DOTFILES ZSHENV ---
[[ -f "$HOME/.config/zsh/zenv" ]] && source "$HOME/.config/zsh/zenv"
# --- END DOTFILES ZSHENV ---
EOF
)"

    if [[ -f "$zshenv" ]] && grep -q "DOTFILES ZSHENV" "$zshenv" 2>/dev/null; then
        return 0
    fi

    if [[ ! -f "$zshenv" ]]; then
        print -r -- "$block" >"$zshenv"
        echo "Created $zshenv with dotfiles zenv"
        return 0
    fi

    local temp_env=""
    temp_env="$(mktemp)"
    print -r -- "$block" >"$temp_env"
    cat "$zshenv" >>"$temp_env"
    mv "$temp_env" "$zshenv"
    echo "Prepended dotfiles zenv block to $zshenv"
}

ensure_dotfiles_zprofile() {
    local zprofile="$HOME/.zprofile"
    local block=""

    block="$(cat <<'EOF'
# --- DOTFILES ZPROFILE ---
[[ -f "$HOME/.config/zsh/zprofile" ]] && source "$HOME/.config/zsh/zprofile"
# --- END DOTFILES ZPROFILE ---
EOF
)"

    if [[ -f "$zprofile" ]] && grep -q "DOTFILES ZPROFILE" "$zprofile" 2>/dev/null; then
        return 0
    fi

    if [[ ! -f "$zprofile" ]]; then
        print -r -- "$block" >"$zprofile"
        echo "Created $zprofile with dotfiles login environment"
        return 0
    fi

    local temp_profile=""
    temp_profile="$(mktemp)"
    print -r -- "$block" >"$temp_profile"
    print -r -- "" >>"$temp_profile"
    cat "$zprofile" >>"$temp_profile"
    mv "$temp_profile" "$zprofile"
    echo "Prepended dotfiles zprofile block to $zprofile"
}

cleanup_duplicate_brew_shellenv_in_zprofile() {
    local zprofile="$1"
    local temp_profile="" removed=0 in_dotfiles_block=0

    [[ -f "$zprofile" ]] || return 0
    grep -q "DOTFILES ZPROFILE" "$zprofile" 2>/dev/null || return 0

    temp_profile="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "# --- DOTFILES ZPROFILE ---" ]]; then
            in_dotfiles_block=1
            print -r -- "$line"
            continue
        fi
        if [[ "$line" == "# --- END DOTFILES ZPROFILE ---" ]]; then
            in_dotfiles_block=0
            print -r -- "$line"
            continue
        fi
        if (( in_dotfiles_block )); then
            print -r -- "$line"
            continue
        fi
        if [[ "$line" == *'brew shellenv'* ]]; then
            removed=1
            continue
        fi
        print -r -- "$line"
    done <"$zprofile" >"$temp_profile"
    mv "$temp_profile" "$zprofile"

    if (( removed )); then
        echo "Removed duplicate brew shellenv from $zprofile (using ~/.config/zsh/zprofile)"
    fi
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

normalize_zprofile() {
    local zprofile="$HOME/.zprofile"

    remove_duplicate_dotfiles_blocks "$zprofile" "DOTFILES ZPROFILE" \
        "# --- DOTFILES ZPROFILE ---" "# --- END DOTFILES ZPROFILE ---"
    cleanup_duplicate_brew_shellenv_in_zprofile "$zprofile"
}

# ~/.zshrc keeps user-owned lines; everything dotfiles owns lives in config/zsh/zshrc.
# Migrates legacy patched blocks (old installs) and inserts the single source line at the top.
ensure_managed_zshrc() {
    local shell_rc="$1" marker="# --- DOTFILES ZSHRC ---" temp_rc="" dropped=""

    touch "$shell_rc"
    if grep -qF "$marker" "$shell_rc"; then
        return 0
    fi

    cp "$shell_rc" "${shell_rc}.pre-managed.bak"
    temp_rc="$(mktemp)"
    dropped="$(mktemp)"

    awk -v dropped="$dropped" '
        function drop(l) { print l >> dropped }
        /^# --- DOTFILES (SETUP|ALIASES|KUBECTL COMPLETION|SYNTAX HIGHLIGHTING|NVM \(lazy\)) ---$/ { blk = 1; drop($0); next }
        /^[[:space:]]+$/ { print ""; next }
        /^# --- END DOTFILES / { blk = 0; drop($0); next }
        blk { drop($0); next }
        /Setup Homebrew zsh-completions/ { cf = 1; drop($0); next }
        cf { drop($0); if ($0 ~ /^[[:space:]]*fi[[:space:]]*$/) cf = 0; next }
        /^[[:space:]]*(export )?ZSH_DISABLE_COMPFIX/ ||
        /^export ZSH=/ || /^ZSH_THEME=/ || /^plugins=\(/ || /^source \$ZSH\/oh-my-zsh\.sh/ ||
        /^export NVM_DIR=/ || /NVM_DIR\/nvm\.sh/ || /NVM_DIR\/bash_completion/ ||
        /sdkman-init\.sh/ || /mise activate/ ||
        /go env GOPATH/ || /kubectl completion zsh/ || /GPG_TTY=\$\(tty\)/ || /^# DOTFILES GPG TTY/ ||
        /^[[:space:]]*unalias (gpr|gprm|kubectl)/ || /^# Override Oh My Zsh git plugin/ ||
        /config\/(fzf\/fzf\.env|zsh\/zoxide\.env|shell\/aliases)/ { drop($0); next }
        { print }
    ' "$shell_rc" >"$temp_rc"

    {
        print -r -- "$marker"
        print -r -- '[[ -f "$HOME/.config/zsh/zshrc" ]] && source "$HOME/.config/zsh/zshrc"'
        print -r -- "# --- END DOTFILES ZSHRC ---"
        print -r -- ""
        cat -s "$temp_rc"
    } >"$shell_rc"
    rm -f "$temp_rc"

    echo "Moved dotfiles-owned setup out of $shell_rc into ~/.config/zsh/zshrc (backup: ${shell_rc}.pre-managed.bak)"
    if grep -E '^(ZSH_THEME|plugins)=' "$dropped" | grep -vE '^(ZSH_THEME="robbyrussell"|plugins=\(git zsh-autosuggestions fast-syntax-highlighting\))$' | grep -q .; then
        echo "Note: custom Oh My Zsh theme/plugins were removed from $shell_rc — put overrides in ~/.config/zsh/pre-omz.zsh:"
        grep -E '^(ZSH_THEME|plugins)=' "$dropped" | sed 's/^/    /'
    fi
    rm -f "$dropped"
}

dotinstall_finalize_zsh() {
    emulate -L zsh

    install_oh_my_zsh
    install_zsh_autosuggestions
    install_fast_syntax_highlighting

    # Homebrew's share dir is group-writable by default, which triggers the compinit
    # "Ignore insecure directories" prompt on every new shell.
    if command -v brew &>/dev/null; then
        BREW_SHARE="$(brew --prefix)/share"
        if [[ -d "$BREW_SHARE" ]]; then
            brew_share_mode_before="$(stat -f '%A' "$BREW_SHARE" 2>/dev/null || true)"
            chmod go-w "$BREW_SHARE"
            brew_share_mode_after="$(stat -f '%A' "$BREW_SHARE" 2>/dev/null || true)"
            if [[ "$brew_share_mode_before" != "$brew_share_mode_after" ]]; then
                echo "Fixed zsh completion permissions on $BREW_SHARE"
            else
                echo "zsh completion permissions already OK on $BREW_SHARE"
            fi
        fi
    fi
}
