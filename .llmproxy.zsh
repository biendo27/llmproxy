#!/usr/bin/env zsh
# CLIProxyAPI bootstrap (loads env + split modules)

# Force-disable shell xtrace to avoid noisy debug output.
unsetopt xtrace
set +x 2>/dev/null || true

_cliproxy_here="$(cd -- "$(dirname -- "${(%):-%N}")" && pwd)"
if [[ -z "${CLIPROXY_HOME:-}" || ! -f "${CLIPROXY_HOME}/.llmproxy.core.zsh" ]]; then
  CLIPROXY_HOME="$_cliproxy_here"
fi
if [[ -z "${CLIPROXY_ENV:-}" || ! -f "${CLIPROXY_ENV}" ]]; then
  CLIPROXY_ENV="${CLIPROXY_HOME}/.llmproxy.env"
fi

[[ -f "$CLIPROXY_ENV" ]] && source "$CLIPROXY_ENV"

# Load modules (if present)
for f in "$CLIPROXY_HOME/.llmproxy.core.zsh" "$CLIPROXY_HOME/.llmproxy.ui.zsh"; do
  [[ -f "$f" ]] && source "$f"
done

# Ensure xtrace remains off after sourcing.
unsetopt xtrace
set +x 2>/dev/null || true

# Apply immediately
if typeset -f _cliproxy_apply >/dev/null 2>&1; then
  _cliproxy_apply
fi
