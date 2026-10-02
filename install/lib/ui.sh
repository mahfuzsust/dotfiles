# Spinner / gum helpers. Sourced by install.sh (zsh).

dotinstall_spin() {
    local title="$1"
    shift
    local use_gum=0
    command -v gum >/dev/null 2>&1 && [[ -t 1 ]] && use_gum=1

    # gum spin exec(3)s argv[0]; zsh functions are not binaries.
    if (( $# == 1 && ${+functions[$1]} )); then
        local fn="$1" tmp="" ret=0
        if (( use_gum )); then
            tmp="$(mktemp "${TMPDIR:-/tmp}/dotinstall-spin.XXXXXX.zsh")"
            {
                print -r -- "typeset -g DOTFILES_DIR=${(q)DOTFILES_DIR}"
                print -r -- "typeset -g CONFIG_DIR=${(q)CONFIG_DIR}"
                print -r -- "typeset -g SHELL_RC=${(q)SHELL_RC}"
                typeset -f
                print -r -- "$fn"
            } >"$tmp"
            gum spin --spinner dot --title "$title" --show-output -- zsh -f "$tmp" || ret=$?
            command rm -f "$tmp"
            return ret
        fi
        print -r -- "$title"
        "$fn"
        return $?
    fi

    if (( use_gum )); then
        gum spin --spinner dot --title "$title" --show-output -- "$@"
    else
        print -r -- "$title"
        "$@"
    fi
}

dotinstall_load_gum_env() {
    [[ -f "$DOTFILES_DIR/config/gum/gum.env" ]] && source "$DOTFILES_DIR/config/gum/gum.env"
}
