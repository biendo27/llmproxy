# Helper/library functions for LLMProxy (split from .llmproxy.core.zsh)

_cliproxy_log() {
  if [[ "${CLIPROXY_LOG_SEP:-1}" != "0" ]]; then
    printf "\n[llmproxy] ------------------------------\n"
  fi
  printf "[llmproxy] %s\n" "$*"
}

_llmproxy_kv() {
  local key="$1"
  local val="$2"
  local width="${3:-16}"
  printf "  %-*s : %s\n" "$width" "$key" "$val"
}

_llmproxy_snapshot_env() {
  if [[ -n "${_LLMPROXY_SAVED:-}" ]]; then
    return 0
  fi
  export _LLMPROXY_SAVED=1
  export _LLMPROXY_ORIG_ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL-}"
  export _LLMPROXY_ORIG_ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN-}"
  export _LLMPROXY_ORIG_ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY-}"
  export _LLMPROXY_ORIG_ANTHROPIC_MODEL="${ANTHROPIC_MODEL-}"
  export _LLMPROXY_ORIG_ANTHROPIC_DEFAULT_OPUS_MODEL="${ANTHROPIC_DEFAULT_OPUS_MODEL-}"
  export _LLMPROXY_ORIG_ANTHROPIC_DEFAULT_SONNET_MODEL="${ANTHROPIC_DEFAULT_SONNET_MODEL-}"
  export _LLMPROXY_ORIG_ANTHROPIC_DEFAULT_HAIKU_MODEL="${ANTHROPIC_DEFAULT_HAIKU_MODEL-}"
  export _LLMPROXY_ORIG_CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC-}"
}

_llmproxy_restore_env() {
  if [[ -z "${_LLMPROXY_SAVED:-}" ]]; then
    unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_MODEL
    unset ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
    return 0
  fi
  export ANTHROPIC_BASE_URL="${_LLMPROXY_ORIG_ANTHROPIC_BASE_URL-}"
  export ANTHROPIC_AUTH_TOKEN="${_LLMPROXY_ORIG_ANTHROPIC_AUTH_TOKEN-}"
  export ANTHROPIC_API_KEY="${_LLMPROXY_ORIG_ANTHROPIC_API_KEY-}"
  export ANTHROPIC_MODEL="${_LLMPROXY_ORIG_ANTHROPIC_MODEL-}"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="${_LLMPROXY_ORIG_ANTHROPIC_DEFAULT_OPUS_MODEL-}"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="${_LLMPROXY_ORIG_ANTHROPIC_DEFAULT_SONNET_MODEL-}"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="${_LLMPROXY_ORIG_ANTHROPIC_DEFAULT_HAIKU_MODEL-}"
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="${_LLMPROXY_ORIG_CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC-}"
}

_llmproxy_clear_proxy_env() {
  if [[ "${ANTHROPIC_BASE_URL-}" == "${CLIPROXY_URL-}" ]]; then
    unset ANTHROPIC_BASE_URL
  fi
  if [[ "${ANTHROPIC_AUTH_TOKEN-}" == "${CLIPROXY_KEY-}" ]]; then
    unset ANTHROPIC_AUTH_TOKEN
  fi
  if [[ -z "${ANTHROPIC_BASE_URL-}" && -z "${ANTHROPIC_AUTH_TOKEN-}" ]]; then
    unset ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
  fi
}

_cliproxy_with_thinking() {
  local model="$1"
  local level="$2"
  if [[ -z "$model" ]]; then
    echo ""
    return
  fi
  if [[ -n "$level" && "$model" != *"("* ]]; then
    echo "${model}(${level})"
  else
    echo "$model"
  fi
}

_cliproxy_current_model() {
  if [[ -n "${CLIPROXY_MODEL:-}" ]]; then
    _cliproxy_with_thinking "$CLIPROXY_MODEL" "${CLIPROXY_THINKING_LEVEL:-}"
    return
  fi
  case "${CLIPROXY_PRESET:-}" in
    claude)      echo "${CLIPROXY_CLAUDE_OPUS:-}" ;;
    codex)       _cliproxy_with_thinking "${CLIPROXY_CODEX_OPUS:-}" "${CLIPROXY_CODEX_THINKING_OPUS:-}" ;;
    gemini)      echo "${CLIPROXY_GEMINI_OPUS:-}" ;;
    antigravity) echo "${CLIPROXY_ANTIGRAVITY_MODEL:-}" ;;
    "")          echo "" ;;
    *)           _cliproxy_with_thinking "${CLIPROXY_PRESET}" "${CLIPROXY_THINKING_LEVEL:-}" ;;
  esac
}

_cliproxy_status_line() {
  local model
  model="$(_cliproxy_current_model)"
  printf "profile=%s | model=%s" "${CLIPROXY_PROFILE:-}" "${model:-<default>}"
}

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

_llmproxy_pick_best() {
  local models="$1"
  shift || true
  local pat match
  for pat in "$@"; do
    match="$(printf "%s\n" "$models" | grep -E "$pat" | tail -n 1)"
    if [[ -n "$match" ]]; then
      echo "$match"
      return 0
    fi
  done
  return 1
}

_llmproxy_model_exists() {
  local models="$1"
  local name="$2"
  [[ -n "$name" ]] && printf "%s\n" "$models" | grep -Fxq -- "$name"
}

_llmproxy_sync_preset_models() {
  local preset="$1"
  [[ "${LLMPROXY_AUTO_SYNC:-1}" == "0" ]] && return 0
  local models
  models="$(_cliproxy_list_models)" || return 1
  case "$preset" in
    claude)
      if ! _llmproxy_model_exists "$models" "${CLIPROXY_CLAUDE_OPUS:-}"; then
        CLIPROXY_CLAUDE_OPUS="$(_llmproxy_pick_best "$models" '^claude-opus-')"
      fi
      if ! _llmproxy_model_exists "$models" "${CLIPROXY_CLAUDE_SONNET:-}"; then
        CLIPROXY_CLAUDE_SONNET="$(_llmproxy_pick_best "$models" '^claude-sonnet-')"
      fi
      if ! _llmproxy_model_exists "$models" "${CLIPROXY_CLAUDE_HAIKU:-}"; then
        CLIPROXY_CLAUDE_HAIKU="$(_llmproxy_pick_best "$models" '^claude-haiku-')"
      fi
      ;;
    codex)
      if ! _llmproxy_model_exists "$models" "${CLIPROXY_CODEX_OPUS:-}"; then
        CLIPROXY_CODEX_OPUS="$(_llmproxy_pick_best "$models" '^gpt-5\.2-codex$' '^gpt-5-codex$' '^gpt-5\.1-codex-max$' '^gpt-5\.1-codex$')"
      fi
      if ! _llmproxy_model_exists "$models" "${CLIPROXY_CODEX_SONNET:-}"; then
        CLIPROXY_CODEX_SONNET="$(_llmproxy_pick_best "$models" '^gpt-5\.1-codex-max$' '^gpt-5\.1-codex$' '^gpt-5-codex$')"
      fi
      if ! _llmproxy_model_exists "$models" "${CLIPROXY_CODEX_HAIKU:-}"; then
        CLIPROXY_CODEX_HAIKU="$(_llmproxy_pick_best "$models" '^gpt-5\.1-codex-mini$' '^gpt-5-codex-mini$')"
      fi
      ;;
    gemini)
      if ! _llmproxy_model_exists "$models" "${CLIPROXY_GEMINI_OPUS:-}"; then
        CLIPROXY_GEMINI_OPUS="$(_llmproxy_pick_best "$models" '^gemini-3-pro' '^gemini-2\.5-pro$')"
      fi
      if ! _llmproxy_model_exists "$models" "${CLIPROXY_GEMINI_SONNET:-}"; then
        CLIPROXY_GEMINI_SONNET="$(_llmproxy_pick_best "$models" '^gemini-3-flash' '^gemini-2\.5-flash$')"
      fi
      if ! _llmproxy_model_exists "$models" "${CLIPROXY_GEMINI_HAIKU:-}"; then
        CLIPROXY_GEMINI_HAIKU="$(_llmproxy_pick_best "$models" '^gemini-2\.5-flash-lite$' '^gemini-2\.5-flash$')"
      fi
      ;;
    *)
      return 0
      ;;
  esac
}

_cliproxy_server_bin() {
  if [[ -n "${CLIPROXY_BIN:-}" && -x "${CLIPROXY_BIN}" ]]; then
    echo "$CLIPROXY_BIN"
    return 0
  fi
  if command -v cli-proxy-api >/dev/null 2>&1; then
    command -v cli-proxy-api
    return 0
  fi
  if [[ -n "${CLIPROXY_SERVER_DIR:-}" && -x "${CLIPROXY_SERVER_DIR}/cli-proxy-api" ]]; then
    echo "${CLIPROXY_SERVER_DIR}/cli-proxy-api"
    return 0
  fi
  _cliproxy_log "cli-proxy-api not found; set CLIPROXY_BIN"
  return 1
}

_cliproxy_server_config() {
  if [[ -n "${CLIPROXY_CONFIG:-}" && -f "${CLIPROXY_CONFIG}" ]]; then
    echo "$CLIPROXY_CONFIG"
    return 0
  fi
  if [[ -n "${CLIPROXY_SERVER_DIR:-}" && -f "${CLIPROXY_SERVER_DIR}/config.yaml" ]]; then
    echo "${CLIPROXY_SERVER_DIR}/config.yaml"
    return 0
  fi
  echo ""
}

_cliproxy_pid_alive() {
  local pid
  [[ -n "${CLIPROXY_PID_FILE:-}" ]] || return 1
  pid="$(cat "$CLIPROXY_PID_FILE" 2>/dev/null)" || return 1
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

_cliproxy_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "" ;;
  esac
}

_llmproxy_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

_llmproxy_mask() {
  local v="$1"
  if [[ -z "$v" ]]; then
    echo ""
    return
  fi
  if (( ${#v} <= 8 )); then
    echo "****"
    return
  fi
  echo "${v:0:4}****${v: -4}"
}

_llmproxy_path_has_local_bin() {
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) return 0 ;;
    *) return 1 ;;
  esac
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

_llmproxy_provider_of_model() {
  local m="$1"
  if [[ -z "$m" ]]; then
    echo ""
    return
  fi
  case "$m" in
    gemini-*) echo "gemini" ;;
    claude-*|anthropic.*) echo "claude" ;;
    gpt-*|o1-*|o3-*|o4-*) echo "codex" ;;
    *) echo "other" ;;
  esac
}

_llmproxy_mixed_providers() {
  local opus="$1"
  local sonnet="$2"
  local haiku="$3"
  local p provider=""

  for p in "$(_llmproxy_provider_of_model "$opus")" \
           "$(_llmproxy_provider_of_model "$sonnet")" \
           "$(_llmproxy_provider_of_model "$haiku")"; do
    [[ -z "$p" ]] && continue
    if [[ -z "$provider" ]]; then
      provider="$p"
    elif [[ "$p" != "$provider" ]]; then
      return 0
    fi
  done
  return 1
}

_llmproxy_warn_mixed_providers() {
  local opus="$1"
  local sonnet="$2"
  local haiku="$3"
  if _llmproxy_mixed_providers "$opus" "$sonnet" "$haiku"; then
    _cliproxy_log "warning: mixed providers across tiers"
    printf "  opus  : %s\n  sonnet: %s\n  haiku : %s\n" "$opus" "$sonnet" "$haiku"
    _cliproxy_log "best practice: keep all tiers in the same provider/preset"
    return 1
  fi
  return 0
}
