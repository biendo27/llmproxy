# System utilities

_cliproxy_is_macos() {
  [[ "$(uname -s | tr '[:upper:]' '[:lower:]')" == "darwin" ]]
}

_llmproxy_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

_llmproxy_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "" ;;
  esac
}

_cliproxy_arch() {
  _llmproxy_arch
}

_llmproxy_default_rc() {
  if [[ -n "${LLMPROXY_RC:-}" ]]; then
    echo "$LLMPROXY_RC"
    return
  fi
  if [[ -n "${SHELL:-}" && "${SHELL}" == *"zsh" ]]; then
    echo "$HOME/.zshrc"
    return
  fi
  if [[ -f "$HOME/.zshrc" ]]; then
    echo "$HOME/.zshrc"
    return
  fi
  echo "$HOME/.bashrc"
}
