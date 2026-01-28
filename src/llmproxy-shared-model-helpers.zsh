# Model helpers and selection utilities

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

_llmproxy_status_line() {
  local model
  model="$(_cliproxy_current_model)"
  printf "profile=%s | model=%s" "${CLIPROXY_PROFILE:-}" "${model:-<default>}"
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
