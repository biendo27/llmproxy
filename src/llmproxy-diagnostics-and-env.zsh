# Diagnostics and env views

llmproxy_doctor() {
  _cliproxy_log "doctor"
  setopt local_options
  unsetopt xtrace verbose
  local os arch missing=0
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(_llmproxy_arch)"
  local w=10
  _llmproxy_kv "os" "$os" "$w"
  _llmproxy_kv "arch" "${arch:-unknown}" "$w"
  _llmproxy_kv "mode" "${LLMPROXY_MODE:-proxy}" "$w"
  _llmproxy_kv "run-mode" "${CLIPROXY_RUN_MODE:-direct}" "$w"
  _llmproxy_kv "home" "${CLIPROXY_HOME:-<not set>}" "$w"

  for cmd in zsh curl python3; do
    if _llmproxy_has_cmd "$cmd"; then
      _llmproxy_kv "$cmd" "ok" "$w"
    else
      _llmproxy_kv "$cmd" "missing" "$w"
      missing=1
    fi
  done
  if _llmproxy_has_cmd fzf; then
    _llmproxy_kv "fzf" "ok (UI picker)" "$w"
  else
    _llmproxy_kv "fzf" "missing (text menu only)" "$w"
  fi

  if [[ -n "${CLIPROXY_URL:-}" && -n "${CLIPROXY_KEY:-}" ]]; then
    if curl -fsS -H "Authorization: Bearer ${CLIPROXY_KEY}" \
      "${CLIPROXY_URL}/v1/models" >/dev/null 2>&1; then
      _llmproxy_kv "server" "reachable (${CLIPROXY_URL})" "$w"
    else
      _llmproxy_kv "server" "not reachable (${CLIPROXY_URL})" "$w"
    fi
  else
    _llmproxy_kv "server" "CLIPROXY_URL/KEY not set" "$w"
  fi

  if [[ "$os" == "darwin" ]]; then
    _llmproxy_kv "launchd" "available" "$w"
    _llmproxy_kv "systemd" "not available (macOS)" "$w"
  else
    _llmproxy_kv "launchd" "not available (Linux)" "$w"
    if _llmproxy_has_cmd systemctl; then
      _llmproxy_kv "systemd" "available" "$w"
    else
      _llmproxy_kv "systemd" "not available" "$w"
    fi
  fi

  if (( missing )); then
    _cliproxy_log "missing prerequisites detected (see README)"
  fi
}

llmproxy_env() {
  _cliproxy_log "env"
  setopt local_options
  unsetopt xtrace verbose
  local w=22
  _llmproxy_kv "mode" "${LLMPROXY_MODE:-proxy}" "$w"
  _llmproxy_kv "run-mode" "${CLIPROXY_RUN_MODE:-direct}" "$w"
  _llmproxy_kv "base_url" "${CLIPROXY_URL:-}" "$w"
  _llmproxy_kv "key" "$(_llmproxy_mask "${CLIPROXY_KEY:-}")" "$w"
  _llmproxy_kv "model" "$(_cliproxy_current_model)" "$w"
  _llmproxy_kv "ANTHROPIC_BASE_URL" "${ANTHROPIC_BASE_URL-}" "$w"
  _llmproxy_kv "ANTHROPIC_AUTH_TOKEN" "$(_llmproxy_mask "${ANTHROPIC_AUTH_TOKEN-}")" "$w"
  _llmproxy_kv "ANTHROPIC_MODEL" "${ANTHROPIC_MODEL-}" "$w"
}

llmproxy_whoami() {
  _cliproxy_log "auth check"
  if [[ -z "${CLIPROXY_URL:-}" || -z "${CLIPROXY_KEY:-}" ]]; then
    _cliproxy_log "CLIPROXY_URL/CLIPROXY_KEY not set"
    return 1
  fi
  local json
  json="$(curl -fsS -H "Authorization: Bearer ${CLIPROXY_KEY}" \
    "${CLIPROXY_URL}/v1/models" 2>/dev/null)" || {
    _cliproxy_log "auth failed (cannot reach /v1/models)"
    return 1
  }
  python3 - <<'PY' "$json" "$(_cliproxy_current_model)"
import json, sys
data = json.loads(sys.argv[1])
cur = sys.argv[2]
models = [m.get("id") for m in data.get("data", []) if isinstance(m, dict)]
models = [m for m in models if m]
print(f"  models    : {len(models)} available")
if cur:
    print(f"  current  : {cur} ({'ok' if cur in models else 'not found'})")
PY
}
