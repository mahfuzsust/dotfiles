# Install progress output. Sourced by install.sh (zsh).

dotinstall_spin() {
    local title="$1"
    shift

    print -r -- "$title"
    if (( $# == 1 && ${+functions[$1]} )); then
        "$1"
        return $?
    fi
    "$@"
}
