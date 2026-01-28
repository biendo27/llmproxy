# Command routing and public CLI

cliproxy_help() {
  cat <<'EOF'
Usage: llmproxy <command> [args]

Commands:
  ui|menu                 Open interactive menu
  init                    Print shell init line for eval
  ui-config               Configure UI (theme/layout/preview/keys)
  use <preset|model>       Switch preset or set model id
  pick-model [filter]      Pick model from /v1/models
  profile <local|local2>   Switch profile
  on|off|toggle            Enable/disable proxy env (Claude official vs proxy)
  setup                    Wizard: env + auto-source + deps
  install [rcfile]         Add auto-source to shell rc
  fix                      Auto-install missing deps
  doctor                   Check environment and dependencies
  env                      Show current env + mode
  whoami                   Check auth via /v1/models
  sync-models <preset>     Sync preset models from /v1/models
  status                   Show current env/model status
  clear                    Clear model override

Server:
  start|stop|restart       Control server (direct/background)
  server-status            Show server status
  run-mode <direct|background> [--persist]
  systemd-install          Install user systemd service (Linux)
  systemd-enable           Enable + start user systemd service (Linux)
  launchd-install          Install user launchd service (macOS)
  launchd-enable           Load + start user launchd service (macOS)
  upgrade                  Download and replace latest binary
  backup                   Create a timestamped backup of the binary

Notes:
  - "cliproxy" is kept as a legacy alias for llmproxy.
EOF
}

cliproxy_status() {
  _cliproxy_log "status"
  setopt local_options
  unsetopt xtrace verbose
  local preset="${CLIPROXY_PRESET:-}"
  local opus="${ANTHROPIC_DEFAULT_OPUS_MODEL:-}"
  local sonnet="${ANTHROPIC_DEFAULT_SONNET_MODEL:-}"
  local haiku="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"

  if [[ -z "$opus" ]]; then
    case "$preset" in
      claude)
        opus="${CLIPROXY_CLAUDE_OPUS:-}"
        sonnet="${CLIPROXY_CLAUDE_SONNET:-}"
        haiku="${CLIPROXY_CLAUDE_HAIKU:-}"
        ;;
      codex)
        opus="${CLIPROXY_CODEX_OPUS:-}"
        sonnet="${CLIPROXY_CODEX_SONNET:-}"
        haiku="${CLIPROXY_CODEX_HAIKU:-}"
        ;;
      gemini)
        opus="${CLIPROXY_GEMINI_OPUS:-}"
        sonnet="${CLIPROXY_GEMINI_SONNET:-}"
        haiku="${CLIPROXY_GEMINI_HAIKU:-}"
        ;;
      antigravity)
        opus="${CLIPROXY_ANTIGRAVITY_MODEL:-}"
        sonnet="$opus"
        haiku="$opus"
        ;;
      *)
        opus="${CLIPROXY_MODEL:-}"
        sonnet="$opus"
        haiku="$opus"
        ;;
    esac
  fi

  [[ -z "$opus" && -n "$sonnet" ]] && opus="$sonnet"
  [[ -z "$opus" && -n "$haiku" ]] && opus="$haiku"
  [[ -z "$sonnet" && -n "$opus" ]] && sonnet="$opus"
  [[ -z "$haiku" && -n "$sonnet" ]] && haiku="$sonnet"

  local w=10
  _llmproxy_kv "profile" "${CLIPROXY_PROFILE:-}" "$w"
  _llmproxy_kv "base_url" "${CLIPROXY_URL:-}" "$w"
  _llmproxy_kv "default" "$(_cliproxy_current_model)" "$w"
  _llmproxy_kv "opus" "$opus" "$w"
  _llmproxy_kv "sonnet" "$sonnet" "$w"
  _llmproxy_kv "haiku" "$haiku" "$w"
  _llmproxy_warn_mixed_providers "$opus" "$sonnet" "$haiku"
}

cliproxy() {
  local _saved_xtrace="${options[xtrace]:-off}"
  local _saved_verbose="${options[verbose]:-off}"
  unsetopt xtrace verbose
  set +x 2>/dev/null || true
  set +v 2>/dev/null || true
  local cmd="${1:-}"
  if (( $# > 0 )); then
    shift
  fi
  local rc=0
  case "$cmd" in
    ""|ui|menu) cliproxy_ui ;;
    init) llmproxy_init ;;
    ui-config|ui-settings) llmproxy_ui_config ;;
    use) cliproxy_use "$@" ;;
    pick-model) cliproxy_pick_model "$@" ;;
    profile) cliproxy_profile "$@" ;;
    on) llmproxy_on ;;
    off) llmproxy_off ;;
    toggle) llmproxy_toggle ;;
    setup) llmproxy_setup ;;
    install) llmproxy_install "$@" ;;
    fix) llmproxy_fix ;;
    doctor) llmproxy_doctor ;;
    env) llmproxy_env ;;
    whoami) llmproxy_whoami ;;
    sync-models) _llmproxy_sync_preset_models "${1:-}"; _cliproxy_apply ;;
    status) cliproxy_status ;;
    clear) cliproxy_clear ;;
    start) cliproxy_start ;;
    stop) cliproxy_stop ;;
    restart) cliproxy_restart ;;
    server-status) cliproxy_server_status ;;
    run-mode) cliproxy_run_mode "$@" ;;
    systemd-install) cliproxy_systemd_install ;;
    systemd-enable) cliproxy_systemd_enable ;;
    launchd-install) cliproxy_launchd_install ;;
    launchd-enable) cliproxy_launchd_enable ;;
    background-install)
      if _cliproxy_is_macos; then
        cliproxy_launchd_install
      else
        cliproxy_systemd_install
      fi
      ;;
    upgrade) cliproxy_upgrade ;;
    backup) cliproxy_backup ;;
    help|-h|--help) cliproxy_help ;;
    *)
      echo "Unknown command: $cmd"
      cliproxy_help
      rc=1
      ;;
  esac
  [[ "$_saved_xtrace" == "on" ]] && setopt xtrace
  [[ "$_saved_verbose" == "on" ]] && setopt verbose
  return $rc
}

llmproxy_help() {
  cliproxy_help
}

llmproxy() {
  cliproxy "$@"
}
