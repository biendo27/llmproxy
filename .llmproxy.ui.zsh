# UI helpers (menu + TUI) - fzf/text only (no gum)

_cliproxy_has_fzf() { command -v fzf >/dev/null 2>&1; }

_cliproxy_choose_level() {
  local prompt="$1"
  local current="$2"
  local level=""
  if _cliproxy_has_fzf; then
    level="$(printf "%s\n" minimal low medium high xhigh auto none | \
      fzf --prompt="${prompt}> " --height=40% --border --no-multi)" || return 1
    echo "$level"
  else
    read -r "level?${prompt} [${current}]: "
    echo "$level"
  fi
}

_cliproxy_action_use_preset() {
  local preset=""
  if _cliproxy_has_fzf; then
    preset="$(printf "%s\n" claude codex gemini antigravity | \
      fzf --prompt="Preset> " --height=40% --border --no-multi)" || return
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
}

_cliproxy_action_use_model_id() {
  read -r "m?Enter model ID: "
  [[ -n "$m" ]] && cliproxy_use "$m"
}

_cliproxy_action_codex_thinking() {
  local t1 t2 t3
  t1="$(_cliproxy_choose_level "Opus" "${CLIPROXY_CODEX_THINKING_OPUS:-}")" || return
  t2="$(_cliproxy_choose_level "Sonnet" "${CLIPROXY_CODEX_THINKING_SONNET:-}")" || return
  t3="$(_cliproxy_choose_level "Haiku" "${CLIPROXY_CODEX_THINKING_HAIKU:-}")" || return
  [[ -n "$t1" ]] && export CLIPROXY_CODEX_THINKING_OPUS="$t1"
  [[ -n "$t2" ]] && export CLIPROXY_CODEX_THINKING_SONNET="$t2"
  [[ -n "$t3" ]] && export CLIPROXY_CODEX_THINKING_HAIKU="$t3"
  _cliproxy_apply
  _cliproxy_log "codex thinking: opus=${CLIPROXY_CODEX_THINKING_OPUS:-} sonnet=${CLIPROXY_CODEX_THINKING_SONNET:-} haiku=${CLIPROXY_CODEX_THINKING_HAIKU:-}"
}

_cliproxy_action_switch_profile() {
  local prof=""
  if _cliproxy_has_fzf; then
    prof="$(printf "%s\n" local local2 | fzf --prompt="Profile> " --height=40% --border --no-multi)" || return
  else
    read -r "pr?Profile (local/local2): "
    prof="$pr"
  fi
  [[ -n "$prof" ]] && cliproxy_profile "$prof"
}

_cliproxy_action_run_mode() {
  local mode=""
  if _cliproxy_has_fzf; then
    mode="$(printf "%s\n" direct systemd | fzf --prompt="Run mode> " --height=40% --border --no-multi)" || return
  else
    read -r "mode?Run mode (direct/systemd): "
  fi
  [[ -n "$mode" ]] && cliproxy_run_mode "$mode"
}

_cliproxy_action_systemd_install() {
  cliproxy_systemd_install
  if _cliproxy_has_fzf; then
    local choice
    choice="$(printf "%s\n" "Enable + start now" "Skip" | fzf --prompt="Systemd> " --height=40% --border --no-multi)" || return
    [[ "$choice" == "Enable + start now" ]] && cliproxy_systemd_enable
  else
    read -r "ans?Enable + start systemd now? (y/N): "
    [[ "$ans" == "y" || "$ans" == "Y" ]] && cliproxy_systemd_enable
  fi
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
    echo "9) Enable proxy (CLIProxyAPI)"
    echo "10) Disable proxy (official Claude)"
    echo "11) Toggle proxy"
    echo "12) Setup wizard (env + deps + rc)"
    echo "13) Auto-fix deps"
    echo "14) Doctor (check deps/server)"
    echo "15) Start server"
    echo "16) Stop server"
    echo "17) Restart server"
    echo "18) Server status"
    echo "19) Set run mode (direct/systemd)"
    echo "20) Install systemd service"
    echo "21) Upgrade CLIProxyAPI"
    echo "22) Backup CLIProxyAPI binary"
    echo "23) Status"
    echo "24) Clear model override"
    echo "25) Exit"
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
      9) llmproxy_on ;;
      10) llmproxy_off ;;
      11) llmproxy_toggle ;;
      12) llmproxy_setup ;;
      13) llmproxy_fix ;;
      14) llmproxy_doctor ;;
      15) cliproxy_start ;;
      16) cliproxy_stop ;;
      17) cliproxy_restart ;;
      18) cliproxy_server_status ;;
      19) _cliproxy_action_run_mode ;;
      20) _cliproxy_action_systemd_install ;;
      21) cliproxy_upgrade ;;
      22) cliproxy_backup ;;
      23) cliproxy_status ;;
      24) cliproxy_clear ;;
      25) break ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

# Arrow-key menu using fzf (if available)
cliproxy_menu() {
  setopt local_options
  unsetopt xtrace
  if ! _cliproxy_has_fzf; then
    _cliproxy_log "fzf not found; using text menu."
    cliproxy_menu_text
    return
  fi

  while true; do
    local choice
    choice=$(printf "%s\n" \
      "Use preset - switch claude/codex/gemini" \
      "Pick model (all) - from /v1/models" \
      "Pick model (codex) - from /v1/models" \
      "Pick model (claude) - from /v1/models" \
      "Pick model (gemini) - from /v1/models" \
      "Use model ID - type manually" \
      "Set Codex thinking levels - opus/sonnet/haiku" \
      "Switch profile - local/local2" \
      "Enable proxy - use CLIProxyAPI" \
      "Disable proxy - use official Claude" \
      "Toggle proxy - switch on/off" \
      "Setup wizard - env + deps + rc" \
      "Auto-fix deps - install missing tools" \
      "Doctor - check deps/server" \
      "Start server - run CLIProxyAPI" \
      "Stop server - stop CLIProxyAPI" \
      "Restart server - restart CLIProxyAPI" \
      "Server status - show running state" \
      "Set run mode - direct/systemd" \
      "Install systemd service - user unit" \
      "Upgrade CLIProxyAPI - latest release" \
      "Backup binary - timestamped copy" \
      "Status - show current env/model" \
      "Clear model override - reset" \
      "Exit" | fzf --prompt="LLMProxy> " --height=40% --border --no-multi --header="$(_cliproxy_status_line)") || return

    case "$choice" in
      "Use preset - "* ) _cliproxy_action_use_preset ;;
      "Pick model (all) - "* ) cliproxy_pick_model ;;
      "Pick model (codex) - "* ) cliproxy_pick_model "codex" "codex" ;;
      "Pick model (claude) - "* ) cliproxy_pick_model "^claude-|^gemini-claude-" "claude" ;;
      "Pick model (gemini) - "* ) cliproxy_pick_model "^gemini-" "gemini" ;;
      "Use model ID - "* ) _cliproxy_action_use_model_id ;;
      "Set Codex thinking levels - "* ) _cliproxy_action_codex_thinking ;;
      "Switch profile - "* ) _cliproxy_action_switch_profile ;;
      "Enable proxy - "* ) llmproxy_on ;;
      "Disable proxy - "* ) llmproxy_off ;;
      "Toggle proxy - "* ) llmproxy_toggle ;;
      "Setup wizard - "* ) llmproxy_setup ;;
      "Auto-fix deps - "* ) llmproxy_fix ;;
      "Doctor - "* ) llmproxy_doctor ;;
      "Start server - "* ) cliproxy_start ;;
      "Stop server - "* ) cliproxy_stop ;;
      "Restart server - "* ) cliproxy_restart ;;
      "Server status - "* ) cliproxy_server_status ;;
      "Set run mode - "* ) _cliproxy_action_run_mode ;;
      "Install systemd service - "* ) _cliproxy_action_systemd_install ;;
      "Upgrade CLIProxyAPI - "* ) cliproxy_upgrade ;;
      "Backup binary - "* ) cliproxy_backup ;;
      "Status - "* ) cliproxy_status ;;
      "Clear model override - "* ) cliproxy_clear ;;
      "Exit") break ;;
    esac
  done
}

# Backward-compatible UI entrypoint
cliproxy_ui() {
  cliproxy_menu
}
