# SSH key and config setup. Sourced by install.sh (zsh).

ensure_ssh_key() {
    if [[ -f "$SSH_KEY" ]]; then
        echo "SSH key already present: $SSH_KEY"
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

ssh_key_loaded() {
    ssh-add -l >/dev/null 2>&1 || return 1
    ssh-add -l 2>/dev/null | grep -qiE 'ed25519|id_ed25519'
}
