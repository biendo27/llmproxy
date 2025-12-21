# Apply environment variables used by Claude Code

_cliproxy_apply() {
  _llmproxy_snapshot_env
  if [[ "${LLMPROXY_MODE:-proxy}" == "direct" ]]; then
    _llmproxy_restore_env
    return
  fi

  if [[ -z "${CLIPROXY_URL:-}" || -z "${CLIPROXY_KEY:-}" ]]; then
    _cliproxy_log "CLIPROXY_URL/CLIPROXY_KEY not set (proxy disabled)"
    return 1
  fi

  export ANTHROPIC_BASE_URL="$CLIPROXY_URL"
  export ANTHROPIC_AUTH_TOKEN="$CLIPROXY_KEY"
  unset ANTHROPIC_API_KEY
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-1}"

  if [[ -n "${CLIPROXY_MODEL:-}" ]]; then
    local direct
    direct="$(_cliproxy_with_thinking "$CLIPROXY_MODEL" "${CLIPROXY_THINKING_LEVEL:-}")"
    export ANTHROPIC_MODEL="$direct"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$direct"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$direct"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$direct"
    return
  fi

  local opus="" sonnet="" haiku="" base=""
  case "${CLIPROXY_PRESET:-}" in
    claude)
      opus="$CLIPROXY_CLAUDE_OPUS"
      sonnet="$CLIPROXY_CLAUDE_SONNET"
      haiku="$CLIPROXY_CLAUDE_HAIKU"
      ;;
    codex)
      opus="$(_cliproxy_with_thinking "${CLIPROXY_CODEX_OPUS:-}" "${CLIPROXY_CODEX_THINKING_OPUS:-}")"
      sonnet="$(_cliproxy_with_thinking "${CLIPROXY_CODEX_SONNET:-}" "${CLIPROXY_CODEX_THINKING_SONNET:-}")"
      haiku="$(_cliproxy_with_thinking "${CLIPROXY_CODEX_HAIKU:-}" "${CLIPROXY_CODEX_THINKING_HAIKU:-}")"
      ;;
    gemini)
      opus="$CLIPROXY_GEMINI_OPUS"
      sonnet="$CLIPROXY_GEMINI_SONNET"
      haiku="$CLIPROXY_GEMINI_HAIKU"
      ;;
    antigravity)
      base="$CLIPROXY_ANTIGRAVITY_MODEL"
      opus="$base"
      sonnet="$base"
      haiku="$base"
      ;;
    "")
      opus=""
      ;;
    *)
      base="$(_cliproxy_with_thinking "${CLIPROXY_PRESET}" "${CLIPROXY_THINKING_LEVEL:-}")"
      opus="$base"
      sonnet="$base"
      haiku="$base"
      ;;
  esac

  [[ -z "$opus" && -n "$sonnet" ]] && opus="$sonnet"
  [[ -z "$opus" && -n "$haiku" ]] && opus="$haiku"
  [[ -z "$sonnet" && -n "$opus" ]] && sonnet="$opus"
  [[ -z "$haiku" && -n "$sonnet" ]] && haiku="$sonnet"

  if ! _llmproxy_warn_mixed_providers "$opus" "$sonnet" "$haiku"; then
    if [[ "${LLMPROXY_STRICT_PROVIDER:-0}" == "1" ]]; then
      _cliproxy_log "strict provider mode: mixed tiers blocked"
      _llmproxy_restore_env
      return 1
    fi
  fi

  if [[ -n "$opus" ]]; then
    export ANTHROPIC_MODEL="$opus"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$opus"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$sonnet"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$haiku"
  else
    unset ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
  fi
}
