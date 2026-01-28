# Model change actions

cliproxy_use() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Usage: cliproxy_use <preset|model-id>"
    echo "Presets: claude | codex | gemini | antigravity"
    return 1
  fi

  case "$name" in
    claude|codex|gemini|antigravity)
      export CLIPROXY_PRESET="$name"
      export CLIPROXY_MODEL=""
      _llmproxy_sync_preset_models "$name"
      ;;
    *)
      export CLIPROXY_MODEL="$name"
      export CLIPROXY_PRESET=""
      ;;
  esac

  _cliproxy_apply
  _cliproxy_log "model: $(_cliproxy_current_model)"
}

cliproxy_profile() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Usage: cliproxy_profile <local|local2>"
    return 1
  fi
  export CLIPROXY_PROFILE="$name"
  [[ -f "$CLIPROXY_ENV" ]] && source "$CLIPROXY_ENV"
  _cliproxy_apply
  _cliproxy_log "profile: $CLIPROXY_PROFILE"
}

cliproxy_clear() {
  unset CLIPROXY_MODEL
  export CLIPROXY_PRESET="${CLIPROXY_PRESET:-claude}"
  _cliproxy_apply
  _cliproxy_log "model override cleared"
}

llmproxy_on() {
  export LLMPROXY_MODE="proxy"
  _cliproxy_apply
  _cliproxy_log "proxy enabled (Claude Code -> CLIProxyAPI)"
}

llmproxy_off() {
  export LLMPROXY_MODE="official"
  _llmproxy_restore_env
  _llmproxy_clear_proxy_env
  _cliproxy_log "proxy disabled (use official Claude)"
}

llmproxy_toggle() {
  if [[ "${LLMPROXY_MODE:-proxy}" == "official" || "${LLMPROXY_MODE:-proxy}" == "direct" ]]; then
    llmproxy_on
  else
    llmproxy_off
  fi
}
