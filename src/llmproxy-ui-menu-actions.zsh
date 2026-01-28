# UI menu actions

_cliproxy_choose_level() {
  setopt local_options
  _cliproxy_ui_no_xtrace
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
  _cliproxy_ui_no_xtrace
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
  _cliproxy_ui_no_xtrace
  _cliproxy_ui_silence_xtrace_begin
  read -r "m?Enter model ID: "
  [[ -n "$m" ]] && cliproxy_use "$m"
  _cliproxy_ui_silence_xtrace_end
}

_cliproxy_action_codex_thinking() {
  setopt local_options
  _cliproxy_ui_no_xtrace
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
  _cliproxy_ui_no_xtrace
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
  _cliproxy_ui_no_xtrace
  _cliproxy_ui_silence_xtrace_begin
  local mode=""
  local -a modes
  modes=(direct background)
  if _cliproxy_has_fzf; then
    mode="$(printf "%s\n" "${modes[@]}" | _cliproxy_fzf_menu "Run mode> " "$(_cliproxy_ui_header)" "40%")" || return
  else
    local prompt="Run mode (${(j:/:)modes}): "
    read -r "mode?$prompt"
  fi
  [[ -n "$mode" ]] && cliproxy_run_mode "$mode"
  _cliproxy_ui_silence_xtrace_end
}

_cliproxy_action_systemd_install() {
  setopt local_options
  _cliproxy_ui_no_xtrace
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

_cliproxy_action_launchd_install() {
  setopt local_options
  _cliproxy_ui_no_xtrace
  _cliproxy_ui_silence_xtrace_begin
  cliproxy_launchd_install
  if _cliproxy_has_fzf; then
    local choice
    choice="$(printf "%s\n" "Load + start now" "Skip" | _cliproxy_fzf_menu "Launchd> " "$(_cliproxy_ui_header)" "40%")" || return
    [[ "$choice" == "Load + start now" ]] && cliproxy_launchd_enable
  else
    read -r "ans?Load + start launchd now? (y/N): "
    [[ "$ans" == "y" || "$ans" == "Y" ]] && cliproxy_launchd_enable
  fi
  _cliproxy_ui_silence_xtrace_end
}

_cliproxy_action_background_install() {
  if _cliproxy_is_macos; then
    _cliproxy_action_launchd_install
  else
    _cliproxy_action_systemd_install
  fi
}
