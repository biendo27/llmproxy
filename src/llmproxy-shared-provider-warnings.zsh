# Provider detection and warnings

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
