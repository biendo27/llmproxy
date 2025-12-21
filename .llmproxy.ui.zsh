# UI helpers (menu + TUI) - fzf/text only (no gum)

typeset -ga _LLMPROXY_XTRACE_STACK

_cliproxy_has_fzf() { command -v fzf >/dev/null 2>&1; }

_cliproxy_ui_silence_xtrace_begin() {
  # Save xtrace state to restore later (stack-safe for nested calls)
  _LLMPROXY_XTRACE_STACK+=("${options[xtrace]:-off}")
  unsetopt xtrace
  set +x 2>/dev/null || true
}

_cliproxy_ui_silence_xtrace_end() {
  local idx=${#_LLMPROXY_XTRACE_STACK[@]}
  local last=""
  (( idx > 0 )) || return 0
  last="${_LLMPROXY_XTRACE_STACK[$idx]}"
  unset "_LLMPROXY_XTRACE_STACK[$idx]"
  if [[ "$last" == "on" ]]; then
    setopt xtrace
  fi
}

_cliproxy_ui_no_xtrace() {
  unsetopt xtrace
  set +x 2>/dev/null || true
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

_cliproxy_fzf_menu() {
  setopt local_options
  unsetopt xtrace
  local prompt="$1"
  local header="$2"
  local height="${3:-60%}"
  shift 3
  fzf --prompt="$prompt" --height="$height" --border --no-multi --info=hidden --header-first \
      --header="$header" \
      --color="$(_cliproxy_ui_colors)" \
      "$@"
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
  printf "profile : %s\n" "${CLIPROXY_PROFILE:-<unset>}"
  printf "mode    : %s\n" "$mode"
  printf "run     : %s\n" "$run_mode"
  printf "base    : %s\n" "${base:-<unset>}"
  printf "key     : %s\n" "${key_mask:-<unset>}"
  printf "preset  : %s\n" "${preset:-<none>}"
  printf "model   : %s\n" "${model:-<default>}"
  printf "tiers   : opus=%s\n" "${ANTHROPIC_DEFAULT_OPUS_MODEL:-<unset>}"
  printf "          sonnet=%s\n" "${ANTHROPIC_DEFAULT_SONNET_MODEL:-<unset>}"
  printf "          haiku=%s\n" "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-<unset>}"
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

_cliproxy_choose_level() {
  setopt local_options
  unsetopt xtrace
  _cliproxy_ui_silence_xtrace_begin
  local prompt="$1"
  local current="$2"
  local level=""
  if _cliproxy_has_fzf; then
    level="$(printf "%s\n" minimal low medium high xhigh auto none | \
      _cliproxy_fzf_menu "${prompt}> " "$(_cliproxy_ui_header)" "40%")" || return 1
    echo "$level"
  else
    read -r "level?${prompt} [${current}]: "
    echo "$level"
  fi
  _cliproxy_ui_silence_xtrace_end
}

_cliproxy_action_use_preset() {
  setopt local_options
  unsetopt xtrace
  _cliproxy_ui_silence_xtrace_begin
  local preset=""
  if _cliproxy_has_fzf; then
    preset="$(printf "%s\n" claude codex gemini antigravity | \
      _cliproxy_fzf_menu "Preset> " "$(_cliproxy_ui_header)" "40%")" || return
  else
    echo "Preset: 1) claude  2) codex  3) gemini  4) antigravity  5) cancel"
    read -r "p?Select: "
    case "$p" in
      1) preset="claude" ;;
      2) preset="codex" ;;
      3) preset="gemini" ;;
      4) preset="antigravity" ;;
      *) preset="" ;;
    esac
  fi
  [[ -n "$preset" ]] && cliproxy_use "$preset"
  _cliproxy_ui_silence_xtrace_end
}

_cliproxy_action_use_model_id() {
  setopt local_options
  unsetopt xtrace
  _cliproxy_ui_silence_xtrace_begin
  read -r "m?Enter model ID: "
  [[ -n "$m" ]] && cliproxy_use "$m"
  _cliproxy_ui_silence_xtrace_end
}

_cliproxy_action_codex_thinking() {
  setopt local_options
  unsetopt xtrace
  _cliproxy_ui_silence_xtrace_begin
  local t1 t2 t3
  t1="$(_cliproxy_choose_level "Opus" "${CLIPROXY_CODEX_THINKING_OPUS:-}")" || return
  t2="$(_cliproxy_choose_level "Sonnet" "${CLIPROXY_CODEX_THINKING_SONNET:-}")" || return
  t3="$(_cliproxy_choose_level "Haiku" "${CLIPROXY_CODEX_THINKING_HAIKU:-}")" || return
  [[ -n "$t1" ]] && export CLIPROXY_CODEX_THINKING_OPUS="$t1"
  [[ -n "$t2" ]] && export CLIPROXY_CODEX_THINKING_SONNET="$t2"
  [[ -n "$t3" ]] && export CLIPROXY_CODEX_THINKING_HAIKU="$t3"
  _cliproxy_apply
  _cliproxy_log "codex thinking: opus=${CLIPROXY_CODEX_THINKING_OPUS:-} sonnet=${CLIPROXY_CODEX_THINKING_SONNET:-} haiku=${CLIPROXY_CODEX_THINKING_HAIKU:-}"
  _cliproxy_ui_silence_xtrace_end
}

_cliproxy_action_switch_profile() {
  setopt local_options
  unsetopt xtrace
  _cliproxy_ui_silence_xtrace_begin
  local prof=""
  if _cliproxy_has_fzf; then
    prof="$(printf "%s\n" local local2 | _cliproxy_fzf_menu "Profile> " "$(_cliproxy_ui_header)" "40%")" || return
  else
    read -r "pr?Profile (local/local2): "
    prof="$pr"
  fi
  [[ -n "$prof" ]] && cliproxy_profile "$prof"
  _cliproxy_ui_silence_xtrace_end
}

_cliproxy_action_run_mode() {
  setopt local_options
  unsetopt xtrace
  _cliproxy_ui_silence_xtrace_begin
  local mode=""
  if _cliproxy_has_fzf; then
    mode="$(printf "%s\n" direct systemd | _cliproxy_fzf_menu "Run mode> " "$(_cliproxy_ui_header)" "40%")" || return
  else
    read -r "mode?Run mode (direct/systemd): "
  fi
  [[ -n "$mode" ]] && cliproxy_run_mode "$mode"
  _cliproxy_ui_silence_xtrace_end
}

_cliproxy_action_systemd_install() {
  setopt local_options
  unsetopt xtrace
  _cliproxy_ui_silence_xtrace_begin
  cliproxy_systemd_install
  if _cliproxy_has_fzf; then
    local choice
    choice="$(printf "%s\n" "Enable + start now" "Skip" | _cliproxy_fzf_menu "Systemd> " "$(_cliproxy_ui_header)" "40%")" || return
    [[ "$choice" == "Enable + start now" ]] && cliproxy_systemd_enable
  else
    read -r "ans?Enable + start systemd now? (y/N): "
    [[ "$ans" == "y" || "$ans" == "Y" ]] && cliproxy_systemd_enable
  fi
  _cliproxy_ui_silence_xtrace_end
}

llmproxy_ui_config() {
  setopt local_options
  unsetopt xtrace
  _cliproxy_ui_silence_xtrace_begin
  if ! _cliproxy_has_fzf; then
    _cliproxy_log "fzf not found; UI config requires fzf."
    return 1
  fi

  while true; do
    local mode="${LLMPROXY_UI_MODE:-expanded}"
    local theme="${LLMPROXY_UI_THEME:-claude}"
    local preview="${LLMPROXY_UI_PREVIEW:-0}"
    local grouped="${LLMPROXY_UI_GROUPED:-1}"
    local keys="${LLMPROXY_UI_QUICK_KEYS:-1}"

    local choice items
    items=$'Mode: '"${mode}"$'\tcompact | expanded | preview\n'
    items+=$'Theme: '"${theme}"$'\tclaude | codex | mono\n'
    items+=$'Preview panel: '"${preview}"$'\t0=off | 1=on\n'
    items+=$'Grouped sections: '"${grouped}"$'\t0=off | 1=on\n'
    items+=$'Quick keys: '"${keys}"$'\tCtrl+P/O/S/E\n'
    items+=$'Back\treturn\n'

    choice="$(printf "%s" "$items" | \
      _cliproxy_fzf_menu "UI> " "$(_cliproxy_ui_header)" "40%" --delimiter=$'\t' --with-nth=1,2 --nth=1,2)" || return

    choice="${choice%%$'\t'*}"
    case "$choice" in
      "Mode:"*)
        mode="$(printf "%s\n" compact expanded preview | _cliproxy_fzf_menu "Mode> " "$(_cliproxy_ui_header)" "40%")" || continue
        export LLMPROXY_UI_MODE="$mode"
        ;;
      "Theme:"*)
        theme="$(printf "%s\n" claude codex mono | _cliproxy_fzf_menu "Theme> " "$(_cliproxy_ui_header)" "40%")" || continue
        export LLMPROXY_UI_THEME="$theme"
        ;;
      "Preview panel:"*)
        preview="$(printf "%s\n" 0 1 | _cliproxy_fzf_menu "Preview> " "$(_cliproxy_ui_header)" "40%")" || continue
        export LLMPROXY_UI_PREVIEW="$preview"
        ;;
      "Grouped sections:"*)
        grouped="$(printf "%s\n" 1 0 | _cliproxy_fzf_menu "Grouped> " "$(_cliproxy_ui_header)" "40%")" || continue
        export LLMPROXY_UI_GROUPED="$grouped"
        ;;
      "Quick keys:"*)
        keys="$(printf "%s\n" 1 0 | _cliproxy_fzf_menu "Quick keys> " "$(_cliproxy_ui_header)" "40%")" || continue
        export LLMPROXY_UI_QUICK_KEYS="$keys"
        ;;
      "Back") break ;;
    esac
  done
  _cliproxy_ui_silence_xtrace_end
}

# Simple text menu (fallback when fzf is unavailable)
cliproxy_menu_text() {
  setopt local_options
  unsetopt xtrace
  while true; do
    echo ""
    echo "== LLMProxy Menu =="
    echo "1) Use preset (claude/codex/gemini/antigravity)"
    echo "2) Pick model from server (all)"
    echo "3) Pick model from server (codex)"
    echo "4) Pick model from server (claude)"
    echo "5) Pick model from server (gemini)"
    echo "6) Use model ID (type it manually)"
    echo "7) Set Codex thinking levels (opus/sonnet/haiku)"
    echo "8) Switch profile (local/local2)"
    echo "9) UI settings"
    echo "10) Enable proxy (CLIProxyAPI)"
    echo "11) Disable proxy (official Claude)"
    echo "12) Toggle proxy"
    echo "13) Setup wizard (env + deps + rc)"
    echo "14) Auto-fix deps"
    echo "15) Doctor (check deps/server)"
    echo "16) Env (show current mode)"
    echo "17) Auth check (/v1/models)"
    echo "18) Start server"
    echo "19) Stop server"
    echo "20) Restart server"
    echo "21) Server status"
    echo "22) Set run mode (direct/systemd)"
    echo "23) Install systemd service"
    echo "24) Upgrade CLIProxyAPI"
    echo "25) Backup CLIProxyAPI binary"
    echo "26) Status"
    echo "27) Clear model override"
    echo "28) Exit"
    read -r "choice?Select: "

    case "$choice" in
      1) _cliproxy_action_use_preset ;;
      2) cliproxy_pick_model ;;
      3) cliproxy_pick_model "codex" "codex" ;;
      4) cliproxy_pick_model "^claude-|^gemini-claude-" "claude" ;;
      5) cliproxy_pick_model "^gemini-" "gemini" ;;
      6) _cliproxy_action_use_model_id ;;
      7) _cliproxy_action_codex_thinking ;;
      8) _cliproxy_action_switch_profile ;;
      9) llmproxy_ui_config ;;
      10) llmproxy_on ;;
      11) llmproxy_off ;;
      12) llmproxy_toggle ;;
      13) llmproxy_setup ;;
      14) llmproxy_fix ;;
      15) llmproxy_doctor ;;
      16) llmproxy_env ;;
      17) llmproxy_whoami ;;
      18) cliproxy_start ;;
      19) cliproxy_stop ;;
      20) cliproxy_restart ;;
      21) cliproxy_server_status ;;
      22) _cliproxy_action_run_mode ;;
      23) _cliproxy_action_systemd_install ;;
      24) cliproxy_upgrade ;;
      25) cliproxy_backup ;;
      26) cliproxy_status ;;
      27) cliproxy_clear ;;
      28) break ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

# Arrow-key menu using fzf (if available)
cliproxy_menu() {
  setopt local_options
  unsetopt xtrace
  _cliproxy_ui_silence_xtrace_begin
  if ! _cliproxy_has_fzf; then
    _cliproxy_log "fzf not found; using text menu."
    cliproxy_menu_text
    return
  fi

  while true; do
    _cliproxy_ui_no_xtrace
    local choice
    local items=""
    if _cliproxy_ui_grouped; then
      items+=$'Actions\t\n'
    fi
    items+=$'Use preset\tSwitch claude/codex/gemini (auto-sync)\n'
    items+=$'Pick model (all)\tChoose from /v1/models\n'
    items+=$'Pick model (codex)\tOverride codex tiers (opus/sonnet/haiku)\n'
    items+=$'Pick model (claude)\tOverride claude tiers (opus/sonnet/haiku)\n'
    items+=$'Pick model (gemini)\tOverride gemini tiers (opus/sonnet/haiku)\n'
    items+=$'Use model ID\tType exact model id\n'
    items+=$'Set Codex thinking levels\topus/sonnet/haiku\n'
    items+=$'Switch profile\tlocal/local2\n'
    items+=$'UI settings\tTheme, layout, preview, shortcuts\n'
    items+=$'Enable proxy\tUse CLIProxyAPI\n'
    items+=$'Disable proxy\tUse official Claude\n'
    items+=$'Toggle proxy\tSwitch on/off\n'
    if _cliproxy_ui_grouped; then
      items+=$'Diagnostics\t\n'
    fi
    items+=$'Status\tShow current env/model\n'
    items+=$'Env\tShow current mode\n'
    items+=$'Auth check\t/v1/models\n'
    items+=$'Doctor\tCheck deps/server\n'
    items+=$'Auto-fix deps\tInstall missing tools\n'
    items+=$'Setup wizard\tEnv + deps + rc\n'
    if _cliproxy_ui_grouped; then
      items+=$'Server\t\n'
    fi
    items+=$'Start server\tRun CLIProxyAPI\n'
    items+=$'Stop server\tStop CLIProxyAPI\n'
    items+=$'Restart server\tRestart CLIProxyAPI\n'
    items+=$'Server status\tShow running state\n'
    items+=$'Set run mode\tDirect/systemd\n'
    items+=$'Install systemd service\tUser unit\n'
    items+=$'Upgrade CLIProxyAPI\tLatest release\n'
    items+=$'Backup binary\tTimestamped copy\n'
    items+=$'Clear model override\tReset direct model\n'
    items+=$'Exit\tClose menu\n'

    _cliproxy_ui_no_xtrace
    local header=""

    local fzf_args=()
    if _cliproxy_ui_quick_keys; then
      fzf_args+=(--expect=ctrl-p,ctrl-o,ctrl-s,ctrl-e)
    fi
    if _cliproxy_ui_preview; then
      export _LLMPROXY_UI_STATUS="$(_cliproxy_ui_status_blob)"
      fzf_args+=(--preview 'printf "%s\n" "$_LLMPROXY_UI_STATUS"' --preview-window=left:33%:wrap)
    fi

    _cliproxy_ui_no_xtrace
    choice=$(printf "%s" "$items" | \
      _cliproxy_fzf_menu "LLMProxy> " "$header" "60%" \
        --delimiter=$'\t' --with-nth=1,2 --nth=1,2 "${fzf_args[@]}") || return
    unset _LLMPROXY_UI_STATUS

    local key=""
    if _cliproxy_ui_quick_keys; then
      key="$(printf "%s\n" "$choice" | sed -n '1p')"
      choice="$(printf "%s\n" "$choice" | sed -n '2p')"
      [[ -n "$choice" ]] || { choice="$key"; key=""; }
      case "$key" in
        ctrl-p) _cliproxy_action_use_preset; continue ;;
        ctrl-o) cliproxy_pick_model; continue ;;
        ctrl-s) cliproxy_status; continue ;;
        ctrl-e) llmproxy_env; continue ;;
      esac
    fi

    choice="${choice%%$'\t'*}"
    case "$choice" in
      "Actions"|"Diagnostics"|"Server"|"") continue ;;
      "Use preset") _cliproxy_action_use_preset ;;
      "Pick model (all)") cliproxy_pick_model ;;
      "Pick model (codex)") cliproxy_pick_model "codex" "codex" ;;
      "Pick model (claude)") cliproxy_pick_model "^claude-|^gemini-claude-" "claude" ;;
      "Pick model (gemini)") cliproxy_pick_model "^gemini-" "gemini" ;;
      "Use model ID") _cliproxy_action_use_model_id ;;
      "Set Codex thinking levels") _cliproxy_action_codex_thinking ;;
      "Switch profile") _cliproxy_action_switch_profile ;;
      "UI settings") llmproxy_ui_config ;;
      "Enable proxy") llmproxy_on ;;
      "Disable proxy") llmproxy_off ;;
      "Toggle proxy") llmproxy_toggle ;;
      "Setup wizard") llmproxy_setup ;;
      "Auto-fix deps") llmproxy_fix ;;
      "Doctor") llmproxy_doctor ;;
      "Env") llmproxy_env ;;
      "Auth check") llmproxy_whoami ;;
      "Start server") cliproxy_start ;;
      "Stop server") cliproxy_stop ;;
      "Restart server") cliproxy_restart ;;
      "Server status") cliproxy_server_status ;;
      "Set run mode") _cliproxy_action_run_mode ;;
      "Install systemd service") _cliproxy_action_systemd_install ;;
      "Upgrade CLIProxyAPI") cliproxy_upgrade ;;
      "Backup binary") cliproxy_backup ;;
      "Status") cliproxy_status ;;
      "Clear model override") cliproxy_clear ;;
      "Exit") break ;;
    esac
  done
  _cliproxy_ui_silence_xtrace_end
}

# Backward-compatible UI entrypoint
cliproxy_ui() {
  cliproxy_menu
}
