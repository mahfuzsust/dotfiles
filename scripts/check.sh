#!/usr/bin/env zsh
# Lint + test the dotfiles: syntax-check every shell file, run shellcheck on bash scripts (if installed), run tests.
# Usage: scripts/check.sh
emulate -L zsh
root="${0:A:h:h}"
cd "$root" || exit 1
fails=0

bad() { print -r -- "FAIL $1"; (( fails++ )) }

for f in install.sh install/lib/*.sh config/shell/*(.) config/zsh/*(.) config/fzf/*.zsh config/load-user-config.zsh tests/*.zsh; do
  case "$f" in *.json|*.env) continue ;; esac
  zsh -n "$f" 2>/dev/null || bad "zsh -n $f"
done

bash_files=()
for f in config/git/*(.) config/shell/interactive-helpers.sh config/*/install*.sh(N); do
  [[ "$(head -1 "$f")" == *bash* ]] || continue
  bash -n "$f" 2>/dev/null || bad "bash -n $f"
  bash_files+=("$f")
done

if (( $+commands[shellcheck] )); then
  shellcheck -S warning "${bash_files[@]}" || bad "shellcheck"
else
  print "skip shellcheck (brew install shellcheck)"
fi

for t in tests/*.zsh; do
  zsh "$t" </dev/null >/dev/null || bad "$t"
done

(( fails )) && { print "$fails check(s) failed"; exit 1 }
print "all checks passed"
