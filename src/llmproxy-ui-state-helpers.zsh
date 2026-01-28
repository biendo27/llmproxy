# UI state helpers

typeset -ga _LLMPROXY_XTRACE_STACK
typeset -ga _LLMPROXY_VERBOSE_STACK

_cliproxy_has_fzf() { command -v fzf >/dev/null 2>&1; }

_cliproxy_ui_silence_xtrace_begin() {
  _LLMPROXY_XTRACE_STACK+=("${options[xtrace]:-off}")
  _LLMPROXY_VERBOSE_STACK+=("${options[verbose]:-off}")
  unsetopt xtrace verbose
  set +x 2>/dev/null || true
  set +v 2>/dev/null || true
}

_cliproxy_ui_silence_xtrace_end() {
  local idx=${#_LLMPROXY_XTRACE_STACK[@]}
  local last="" vlast=""
  (( idx > 0 )) || return 0
  last="${_LLMPROXY_XTRACE_STACK[$idx]}"
  vlast="${_LLMPROXY_VERBOSE_STACK[$idx]}"
  unset "_LLMPROXY_XTRACE_STACK[$idx]"
  unset "_LLMPROXY_VERBOSE_STACK[$idx]"
  if [[ "$last" == "on" ]]; then
    setopt xtrace
  fi
  if [[ "$vlast" == "on" ]]; then
    setopt verbose
  fi
}

_cliproxy_ui_no_xtrace() {
  unsetopt xtrace verbose
  set +x 2>/dev/null || true
  set +v 2>/dev/null || true
}

_cliproxy_ui_theme() {
  echo "${LLMPROXY_UI_THEME:-claude}"
}

_cliproxy_ui_mode() {
  echo "${LLMPROXY_UI_MODE:-expanded}"
}

_cliproxy_ui_grouped() {
  [[ "${LLMPROXY_UI_GROUPED:-1}" != "0" ]]
}

_cliproxy_ui_preview() {
  [[ "${LLMPROXY_UI_PREVIEW:-0}" == "1" || "$(_cliproxy_ui_mode)" == "preview" ]]
}

_cliproxy_ui_quick_keys() {
  [[ "${LLMPROXY_UI_QUICK_KEYS:-1}" == "1" ]]
}

_cliproxy_ui_colors() {
  case "$(_cliproxy_ui_theme)" in
    codex)
      printf "%s" "fg:252,bg:234,hl:45,fg+:255,bg+:236,hl+:45,info:245,prompt:45,pointer:45,marker:45,spinner:45,header:245,border:238"
      ;;
    mono)
      printf "%s" "fg:250,bg:234,hl:250,fg+:255,bg+:236,hl+:255,info:244,prompt:250,pointer:250,marker:250,spinner:250,header:244,border:238"
      ;;
    *)
      printf "%s" "fg:252,bg:235,hl:208,fg+:255,bg+:236,hl+:208,info:244,prompt:208,pointer:208,marker:208,spinner:208,header:244,border:238"
      ;;
  esac
}

_llmproxy_menu_item() {
  local label="$1"
  local desc="$2"
  local width="${3:-28}"
  printf "%-*s\t%s" "$width" "$label" "$desc"
}

_llmproxy_menu_section() {
  local label="$1"
  local width="${2:-28}"
  printf "%-*s\t" "$width" "$label"
}

_cliproxy_ui_status_blob() {
  local mode="${LLMPROXY_MODE:-proxy}"
  local run_mode="${CLIPROXY_RUN_MODE:-direct}"
  local preset="${CLIPROXY_PRESET:-}"
  local base="${CLIPROXY_URL:-}"
  local key_mask="$(_llmproxy_mask "${CLIPROXY_KEY:-}")"
  local model="$(_cliproxy_current_model)"
  local warn=""
  if _llmproxy_mixed_providers "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}" "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}" "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"; then
    warn="WARNING: mixed providers across tiers"
  fi

  printf "LLMProxy Status\n"
  printf "--------------\n"
  local w=8
  _llmproxy_kv "profile" "${CLIPROXY_PROFILE:-<unset>}" "$w"
  _llmproxy_kv "mode" "$mode" "$w"
  _llmproxy_kv "run" "$run_mode" "$w"
  _llmproxy_kv "base" "${base:-<unset>}" "$w"
  _llmproxy_kv "key" "${key_mask:-<unset>}" "$w"
  _llmproxy_kv "preset" "${preset:-<none>}" "$w"
  _llmproxy_kv "model" "${model:-<default>}" "$w"
  _llmproxy_kv "opus" "${ANTHROPIC_DEFAULT_OPUS_MODEL:-<unset>}" "$w"
  _llmproxy_kv "sonnet" "${ANTHROPIC_DEFAULT_SONNET_MODEL:-<unset>}" "$w"
  _llmproxy_kv "haiku" "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-<unset>}" "$w"
  [[ -n "$warn" ]] && printf "\n%s\n" "$warn"
}

_cliproxy_ui_header() {
  local mode="${LLMPROXY_MODE:-proxy}"
  local profile="${CLIPROXY_PROFILE:-}"
  local run_mode="${CLIPROXY_RUN_MODE:-direct}"
  local model="$(_cliproxy_current_model)"
  local base="${CLIPROXY_URL:-}"
  local warn=""
  if _llmproxy_mixed_providers "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}" "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}" "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"; then
    warn="Warning: mixed providers across tiers"
  fi

  if [[ "$(_cliproxy_ui_mode)" == "compact" ]]; then
    printf "LLMProxy | profile=%s | mode=%s | run=%s | model=%s" "${profile:-?}" "$mode" "$run_mode" "${model:-<default>}"
    return
  fi

  printf "LLMProxy  |  profile=%s  mode=%s  run=%s\n" "${profile:-?}" "$mode" "$run_mode"
  printf "model: %s\n" "${model:-<default>}"
  printf "base : %s\n" "${base:-<unset>}"
  [[ -n "$warn" ]] && printf "%s\n" "$warn"
  printf "Type to filter • Enter to run • Esc to exit"
}
