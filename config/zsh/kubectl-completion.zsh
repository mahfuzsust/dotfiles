# kubectl completion, cached — `source <(kubectl completion zsh)` forks kubectl on every shell start.
# The cache is regenerated when the kubectl binary is newer than it.

if command -v kubectl >/dev/null 2>&1; then
  _kubectl_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/kubectl-completion.zsh"
  _kubectl_bin="$(whence -p kubectl)"

  if [[ ! -s "$_kubectl_cache" || "$_kubectl_bin" -nt "$_kubectl_cache" ]]; then
    mkdir -p "${_kubectl_cache:h}"
    kubectl completion zsh >"$_kubectl_cache" 2>/dev/null
  fi
  [[ -s "$_kubectl_cache" ]] && source "$_kubectl_cache"

  unset _kubectl_cache _kubectl_bin
fi
