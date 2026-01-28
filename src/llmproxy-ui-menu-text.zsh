# Text-based menu (fallback)

cliproxy_menu_text() {
  emulate -L zsh
  _cliproxy_ui_no_xtrace
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
    echo "22) Set run mode (direct/background)"
    echo "23) Install background service (systemd/launchd)"
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
      23) _cliproxy_action_background_install ;;
      24) cliproxy_upgrade ;;
      25) cliproxy_backup ;;
      26) cliproxy_status ;;
      27) cliproxy_clear ;;
      28) break ;;
      *) echo "Invalid choice." ;;
    esac
  done
}
