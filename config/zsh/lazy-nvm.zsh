# Lazy nvm — sourced from ~/.zshrc (DOTFILES NVM block). Loading nvm.sh eagerly costs ~0.8s per shell.
# The first call to nvm/node/npm/npx/corepack loads nvm.sh, drops the stubs, then re-runs the command.

export NVM_DIR="${NVM_DIR:-$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "$HOME/.nvm" || printf %s "$XDG_CONFIG_HOME/nvm")}"

_lazy_nvm_cmds=(nvm node npm npx corepack)

_lazy_nvm_load() {
  unfunction "${_lazy_nvm_cmds[@]}" 2>/dev/null
  [[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"
  [[ -s "$NVM_DIR/bash_completion" ]] && source "$NVM_DIR/bash_completion"
}

if [[ -s "$NVM_DIR/nvm.sh" ]]; then
  for _cmd in "${_lazy_nvm_cmds[@]}"; do
    eval "${_cmd}() { _lazy_nvm_load; ${_cmd} \"\$@\"; }"
  done
  unset _cmd
fi
