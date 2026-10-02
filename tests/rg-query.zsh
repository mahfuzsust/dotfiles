#!/usr/bin/env zsh
# Tests for the rg wrapper, fzf reloader, and s wildcard parsing. Run: zsh tests/rg-query.zsh
emulate -L zsh
setopt no_aliases

root="${0:A:h:h}"
fails=0
ok()   { print -r -- "ok   $1" }
fail() { print -r -- "FAIL $1"; (( fails++ )) }
check() { # name expected actual
  [[ "$2" == "$3" ]] && ok "$1" || { fail "$1"; print -r -- "     want: $2"$'\n'"     got:  $3" }
}

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/cfg/fzf" "$tmp/proj"
ln -s "$root/config/fzf/rg-fzf-lib.zsh"    "$tmp/cfg/fzf/"
ln -s "$root/config/fzf/rg-fzf-reload.zsh" "$tmp/cfg/fzf/"
print gum  > "$tmp/proj/README.md"
print gum  > "$tmp/proj/notes.txt"
export DOTFILES_CONFIG="$tmp/cfg" RIPGREP_CONFIG_PATH=/dev/null

source "$root/config/fzf/rg-fzf-lib.zsh"

# --- _fzf_rg_query_incomplete
_fzf_rg_query_incomplete;            check "empty query is incomplete" 0 $?
_fzf_rg_query_incomplete -g;         check "bare -g is incomplete" 0 $?
_fzf_rg_query_incomplete -g 'REA*';  check "-g with value is complete" 1 $?
_fzf_rg_query_incomplete -i gum;     check "plain query is complete" 1 $?

# --- reloader: glob reaches rg unexpanded, incomplete query prints nothing
# fzf passes the whole query as ONE argument ({q}); mimic that.
reload() { zsh -f "$tmp/cfg/fzf/rg-fzf-reload.zsh" "$tmp/proj" "$*" }
# Reloader must not hang when stdin is an open pipe (as under fzf).
check "reload survives open stdin pipe" "README.md:1:gum" "$(sleep 20 | timeout 5 zsh -f "$tmp/cfg/fzf/rg-fzf-reload.zsh" "$tmp/proj" "-g REA* gum")"
check "reload -g REA* gum" "README.md:1:gum" "$(reload -g 'REA*' gum)"
check "reload quoted glob" "README.md:1:gum" "$(reload -g "'REA*'" gum)"
check "reload -i -t md gum" "README.md:1:gum" "$(reload -i -t md gum)"
check "reload bare -g is silent" "" "$(reload -g)"
check "reload no args is silent" "" "$(reload)"
check "reload missing root is silent" "" "$(zsh -f "$tmp/cfg/fzf/rg-fzf-reload.zsh" /nonexistent gum)"

# --- rg alias: noglob keeps the pattern away from zsh globbing
cd "$tmp/proj"
setopt aliases
source "$root/config/shell/rg"
check "rg alias noglob" "README.md" "$(eval "rg -l -g REA* gum </dev/null")"

(( fails )) && { print "$fails failed"; exit 1 }
print "all passed"
