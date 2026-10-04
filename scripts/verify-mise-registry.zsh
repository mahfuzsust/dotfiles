#!/usr/bin/env zsh
# Ensure every tool in config/mise/config.toml exists in `mise registry` before relying on it.
# Usage: scripts/verify-mise-registry.zsh
emulate -L zsh

root="${0:A:h:h}"
config="$root/config/mise/config.toml"
fails=0
tools=()
in_tools=0

if ! command -v mise >/dev/null 2>&1; then
  print -r -- "skip verify-mise-registry (mise not on PATH; brew install mise)"
  exit 0
fi

[[ -f "$config" ]] || { print -r -- "FAIL missing $config" >&2; exit 1 }

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" == '[tools]' ]] && { in_tools=1; continue }
  [[ "$line" == \[* ]] && { in_tools=0; continue }
  (( in_tools )) || continue
  [[ "$line" =~ '^[[:space:]]*#' ]] && continue
  [[ "$line" =~ '^[[:space:]]*$' ]] && continue
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ "$line" == *"="* ]] || continue
  key="${line%%=*}"
  key="${key//\"/}"
  key="${key// /}"
  [[ -n "$key" ]] && tools+=("$key")
done <"$config"

(( ${#tools} )) || { print -r -- "FAIL no [tools] entries in $config" >&2; exit 1 }

for tool in "${tools[@]}"; do
  if mise registry "$tool" >/dev/null 2>&1; then
    print -r -- "OK  $tool"
  else
    print -r -- "FAIL $tool (not in mise registry)" >&2
    (( fails++ ))
  fi
done

(( fails )) && { print -r -- "$fails tool(s) missing from mise registry" >&2; exit 1 }
print -r -- "mise registry: ${#tools} tool(s) OK"
