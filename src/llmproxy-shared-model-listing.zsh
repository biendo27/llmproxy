# Model listing from server

_cliproxy_list_models() {
  if [[ -z "${CLIPROXY_URL:-}" || -z "${CLIPROXY_KEY:-}" ]]; then
    _cliproxy_log "CLIPROXY_URL/CLIPROXY_KEY not set"
    return 1
  fi
  local json
  json="$(curl -fsS -H "Authorization: Bearer ${CLIPROXY_KEY}" \
    "${CLIPROXY_URL}/v1/models" 2>/dev/null)" || return 1

  python3 - <<'PY' "$json"
import json, sys
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(1)
models = [m.get("id") for m in data.get("data", []) if isinstance(m, dict)]
for m in sorted(set(filter(None, models))):
    print(m)
PY
}
