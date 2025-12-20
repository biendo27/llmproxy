#!/usr/bin/env zsh
# CLIProxyAPI bootstrap (loads env + split modules)

CLIPROXY_HOME="${CLIPROXY_HOME:-$(cd -- "$(dirname -- "${(%):-%N}")" && pwd)}"
CLIPROXY_ENV="${CLIPROXY_ENV:-$CLIPROXY_HOME/.cliproxy.env}"

[[ -f "$CLIPROXY_ENV" ]] && source "$CLIPROXY_ENV"

# Load modules (if present)
for f in "$CLIPROXY_HOME/.cliproxy.core.zsh" "$CLIPROXY_HOME/.cliproxy.ui.zsh"; do
  [[ -f "$f" ]] && source "$f"
done

# Apply immediately
if typeset -f _cliproxy_apply >/dev/null 2>&1; then
  _cliproxy_apply
fi
