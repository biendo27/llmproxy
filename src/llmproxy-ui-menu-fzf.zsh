# fzf-based menu

_cliproxy_fzf_menu() {
  setopt local_options
  _cliproxy_ui_no_xtrace
  local prompt="$1"
  local header="$2"
  local height="${3:-60%}"
  shift 3
  fzf --prompt="$prompt" --height="$height" --border --no-multi --info=hidden --header-first \
      --header="$header" \
      --color="$(_cliproxy_ui_colors)" \
      "$@"
}

cliproxy_menu() {
  emulate -L zsh
  _cliproxy_ui_no_xtrace
  _cliproxy_ui_silence_xtrace_begin
  if ! _cliproxy_has_fzf; then
    _cliproxy_log "fzf not found; using text menu."
    cliproxy_menu_text
    return
  fi

  while true; do
    local -a item_lines=()
    _cliproxy_ui_no_xtrace
    local choice
    local items=""
    local item_w=28
    if _cliproxy_ui_grouped; then
      item_lines+=("$(_llmproxy_menu_section "Actions" "$item_w")")
    fi
    item_lines+=("$(_llmproxy_menu_item "Use preset" "Switch claude/codex/gemini (auto-sync)" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Pick model (all)" "Choose from /v1/models" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Pick model (codex)" "Override codex tiers (opus/sonnet/haiku)" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Pick model (claude)" "Override claude tiers (opus/sonnet/haiku)" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Pick model (gemini)" "Override gemini tiers (opus/sonnet/haiku)" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Use model ID" "Type exact model id" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Set Codex thinking levels" "opus/sonnet/haiku" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Switch profile" "local/local2" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "UI settings" "Theme, layout, preview, shortcuts" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Enable proxy" "Use CLIProxyAPI" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Disable proxy" "Use official Claude" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Toggle proxy" "Switch on/off" "$item_w")")
    if _cliproxy_ui_grouped; then
      item_lines+=("$(_llmproxy_menu_section "Diagnostics" "$item_w")")
    fi
    item_lines+=("$(_llmproxy_menu_item "Status" "Show current env/model" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Env" "Show current mode" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Auth check" "/v1/models" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Doctor" "Check deps/server" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Auto-fix deps" "Install missing tools" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Setup wizard" "Env + deps + rc" "$item_w")")
    if _cliproxy_ui_grouped; then
      item_lines+=("$(_llmproxy_menu_section "Server" "$item_w")")
    fi
    item_lines+=("$(_llmproxy_menu_item "Start server" "Run CLIProxyAPI" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Stop server" "Stop CLIProxyAPI" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Restart server" "Restart CLIProxyAPI" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Server status" "Show running state" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Set run mode" "Direct/background" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Install background service" "systemd (Linux) / launchd (macOS)" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Upgrade CLIProxyAPI" "Latest release" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Backup binary" "Timestamped copy" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Clear model override" "Reset direct model" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Exit" "Close menu" "$item_w")")
    items="${(F)item_lines}"

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
    choice="${choice%"${choice##*[![:space:]]}"}"
    if [[ "$choice" == "Actions" || "$choice" == "Diagnostics" || "$choice" == "Server" || -z "$choice" ]]; then
      continue
    fi
    case "$choice" in
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
      "Install background service") _cliproxy_action_background_install ;;
      "Upgrade CLIProxyAPI") cliproxy_upgrade ;;
      "Backup binary") cliproxy_backup ;;
      "Status") cliproxy_status ;;
      "Clear model override") cliproxy_clear ;;
      "Exit") break ;;
    esac
  done
  _cliproxy_ui_silence_xtrace_end
}

cliproxy_ui() {
  cliproxy_menu
}
