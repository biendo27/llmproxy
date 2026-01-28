# Path helper utilities

_llmproxy_path_has_local_bin() {
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) return 0 ;;
    *) return 1 ;;
  esac
}
