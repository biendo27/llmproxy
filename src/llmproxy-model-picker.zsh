# Model picker and selection menu

cliproxy_pick_model() {
  emulate -L zsh
  setopt local_options
  local _ui_silenced=0
  if typeset -f _cliproxy_ui_silence_xtrace_begin >/dev/null 2>&1; then
    _cliproxy_ui_silence_xtrace_begin
    _ui_silenced=1
  fi
  {
  unsetopt xtrace
  set +x 2>/dev/null || true
  local filter="${1:-}"
  local mode="${2:-}"
  local picker="${3:-}"
  local models default_label
  default_label="Default (keep current)"
  models="$(_cliproxy_list_models)" || {
    _cliproxy_log "failed to fetch /v1/models (is CLIProxyAPI running?)"
    return 1
  }

  if [[ -n "$filter" ]]; then
    models="$(printf "%s\n" "$models" | grep -Ei -- "$filter" || true)"
  fi

  if [[ -z "$models" ]]; then
    _cliproxy_log "no models matched filter: ${filter:-<none>} (default only)"
    models=""
  fi

  _cliproxy_pick_from_list() {
    local list="$1"
    local header="$2"
    local picked=""
    unsetopt xtrace
    set +x 2>/dev/null || true
    local full_header="$header"
    if typeset -f _cliproxy_ui_header >/dev/null 2>&1; then
      full_header="$(_cliproxy_ui_header)"$'\n'"$header"
    fi
    if [[ "$picker" == "gum" ]] && command -v gum >/dev/null 2>&1; then
      local term=""
      if gum choose --help 2>&1 | grep -q -- '--filter'; then
        picked="$(printf "%s\n" "$list" | gum choose --header "$full_header" --filter)" || return 1
      else
        term="$(gum input --prompt "Filter (optional): " --placeholder "type to narrow")" || return 1
        if [[ -n "$term" ]]; then
          list="$(printf "%s\n" "$list" | grep -Ei -- "$term" || true)"
          if ! printf "%s\n" "$list" | grep -Fxq -- "$default_label"; then
            list="$(printf "%s\n%s\n" "$default_label" "$list")"
          fi
        fi
        [[ -n "$list" ]] || list="$default_label"
        picked="$(printf "%s\n" "$list" | gum choose --header "$full_header")" || return 1
      fi
    elif command -v fzf >/dev/null 2>&1; then
      if typeset -f _cliproxy_fzf_menu >/dev/null 2>&1; then
        picked="$(printf "%s\n" "$list" | _cliproxy_fzf_menu "Model> " "$full_header" "50%")" || return 1
      else
        picked="$(printf "%s\n" "$list" | fzf --prompt="Model> " --height=50% --border --no-multi --info=hidden --header-first \
          --header="$full_header" \
          --color=fg:252,bg:235,hl:208,fg+:255,bg+:236,hl+:208,info:244,prompt:208,pointer:208,marker:208,spinner:208,header:244,border:238)" || return 1
      fi
    else
      _cliproxy_log "fzf not found; printing list."
      printf "%s\n" "$list"
      read -r "m?Enter model ID (empty = keep current): "
      picked="$m"
    fi
    printf "%s" "$picked"
  }

  case "$mode" in
    codex|claude|gemini)
      _llmproxy_sync_preset_models "$mode"
      local picked current list header changed=0
      local tiers=("opus" "sonnet" "haiku")
      for tier in "${tiers[@]}"; do
        case "$mode:$tier" in
          codex:opus)
            current="$(_cliproxy_with_thinking "${CLIPROXY_CODEX_OPUS:-}" "${CLIPROXY_CODEX_THINKING_OPUS:-}")"
            ;;
          codex:sonnet)
            current="$(_cliproxy_with_thinking "${CLIPROXY_CODEX_SONNET:-}" "${CLIPROXY_CODEX_THINKING_SONNET:-}")"
            ;;
          codex:haiku)
            current="$(_cliproxy_with_thinking "${CLIPROXY_CODEX_HAIKU:-}" "${CLIPROXY_CODEX_THINKING_HAIKU:-}")"
            ;;
          claude:opus) current="${CLIPROXY_CLAUDE_OPUS:-}" ;;
          claude:sonnet) current="${CLIPROXY_CLAUDE_SONNET:-}" ;;
          claude:haiku) current="${CLIPROXY_CLAUDE_HAIKU:-}" ;;
          gemini:opus) current="${CLIPROXY_GEMINI_OPUS:-}" ;;
          gemini:sonnet) current="${CLIPROXY_GEMINI_SONNET:-}" ;;
          gemini:haiku) current="${CLIPROXY_GEMINI_HAIKU:-}" ;;
          *) current="" ;;
        esac

        list="$default_label"
        if [[ -n "$models" ]]; then
          list="$(printf "%s\n%s\n" "$default_label" "$models")"
        fi
        header="Override ${mode} ${tier} model (current: ${current:-<unset>})"
        picked="$(_cliproxy_pick_from_list "$list" "$header")" || { _cliproxy_log "skip ${tier} (cancelled)"; continue; }
        [[ -z "$picked" || "$picked" == "$default_label" ]] && continue

        case "$mode:$tier" in
          codex:opus) export CLIPROXY_CODEX_OPUS="$picked" ;;
          codex:sonnet) export CLIPROXY_CODEX_SONNET="$picked" ;;
          codex:haiku) export CLIPROXY_CODEX_HAIKU="$picked" ;;
          claude:opus) export CLIPROXY_CLAUDE_OPUS="$picked" ;;
          claude:sonnet) export CLIPROXY_CLAUDE_SONNET="$picked" ;;
          claude:haiku) export CLIPROXY_CLAUDE_HAIKU="$picked" ;;
          gemini:opus) export CLIPROXY_GEMINI_OPUS="$picked" ;;
          gemini:sonnet) export CLIPROXY_GEMINI_SONNET="$picked" ;;
          gemini:haiku) export CLIPROXY_GEMINI_HAIKU="$picked" ;;
        esac
        changed=1
      done

      export CLIPROXY_PRESET="$mode"
      export CLIPROXY_MODEL=""
      _cliproxy_apply
      if (( changed )); then
        _cliproxy_log "$mode tiers updated"
      else
        _cliproxy_log "kept current $mode preset"
      fi
      ;;
    *)
      local picked=""
      local list="$default_label"
      if [[ -n "$models" ]]; then
        list="$(printf "%s\n%s\n" "$default_label" "$models")"
      fi
      picked="$(_cliproxy_pick_from_list "$list" "$(_cliproxy_status_line)")" || return
      [[ -n "$picked" && "$picked" != "$default_label" ]] || { _cliproxy_log "kept current preset/model"; return 0; }
      cliproxy_use "$picked"
      ;;
  esac
  } always {
    (( _ui_silenced )) && _cliproxy_ui_silence_xtrace_end
  }
}
