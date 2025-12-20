#!/usr/bin/env zsh
# CLIProxyAPI bootstrap (loads env + split modules)

_cliproxy_here="$(cd -- "$(dirname -- "${(%):-%N}")" && pwd)"
if [[ -z "${CLIPROXY_HOME:-}" || ! -f "${CLIPROXY_HOME}/.cliproxy.core.zsh" ]]; then
  CLIPROXY_HOME="$_cliproxy_here"
fi
if [[ -z "${CLIPROXY_ENV:-}" || ! -f "${CLIPROXY_ENV}" ]]; then
  CLIPROXY_ENV="${CLIPROXY_HOME}/.cliproxy.env"
fi

[[ -f "$CLIPROXY_ENV" ]] && source "$CLIPROXY_ENV"

# Load modules (if present)
for f in "$CLIPROXY_HOME/.cliproxy.core.zsh" "$CLIPROXY_HOME/.cliproxy.ui.zsh"; do
  [[ -f "$f" ]] && source "$f"
done

# Apply immediately
if typeset -f _cliproxy_apply >/dev/null 2>&1; then
  _cliproxy_apply
fi
