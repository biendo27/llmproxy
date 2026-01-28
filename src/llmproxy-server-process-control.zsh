# Server start/stop helpers

cliproxy_start() {
  local mode="${CLIPROXY_RUN_MODE:-direct}"
  [[ "$mode" == "systemd" ]] && mode="background"
  if [[ "$mode" == "background" ]]; then
    if _cliproxy_is_macos; then
      cliproxy_launchd_start
      return $?
    else
      if ! command -v systemctl >/dev/null 2>&1; then
        _cliproxy_log "systemctl not found (systemd unavailable on this OS)"
        return 1
      fi
      local svc="${CLIPROXY_SYSTEMD_SERVICE:-cliproxyapi}"
      systemctl --user start "${svc}.service"
      _cliproxy_log "systemd start: ${svc}.service"
      return 0
    fi
  fi

  local bin config log_dir run_log pid_file
  bin="$(_cliproxy_server_bin)" || return 1
  config="$(_cliproxy_server_config)"
  log_dir="${CLIPROXY_LOG_DIR:-$HOME}"
  run_log="${CLIPROXY_RUN_LOG:-$log_dir/cliproxyapi.out.log}"
  pid_file="${CLIPROXY_PID_FILE:-$log_dir/cliproxyapi.pid}"
  [[ -z "${CLIPROXY_LOG_DIR:-}" ]] && export CLIPROXY_LOG_DIR="$log_dir"
  [[ -z "${CLIPROXY_RUN_LOG:-}" ]] && export CLIPROXY_RUN_LOG="$run_log"
  [[ -z "${CLIPROXY_PID_FILE:-}" ]] && export CLIPROXY_PID_FILE="$pid_file"
  mkdir -p "$log_dir"
  if _cliproxy_pid_alive; then
    _cliproxy_log "already running (pid $(cat "$CLIPROXY_PID_FILE"))"
    return 0
  fi
  if [[ -n "$config" ]]; then
    nohup "$bin" --config "$config" >> "$CLIPROXY_RUN_LOG" 2>&1 &
  else
    nohup "$bin" >> "$CLIPROXY_RUN_LOG" 2>&1 &
  fi
  echo $! > "$CLIPROXY_PID_FILE"
  _cliproxy_log "started (pid $!)"
}

cliproxy_stop() {
  local mode="${CLIPROXY_RUN_MODE:-direct}"
  [[ "$mode" == "systemd" ]] && mode="background"
  if [[ "$mode" == "background" ]]; then
    if _cliproxy_is_macos; then
      cliproxy_launchd_stop
      return $?
    else
      if ! command -v systemctl >/dev/null 2>&1; then
        _cliproxy_log "systemctl not found (systemd unavailable on this OS)"
        return 1
      fi
      local svc="${CLIPROXY_SYSTEMD_SERVICE:-cliproxyapi}"
      systemctl --user stop "${svc}.service"
      _cliproxy_log "systemd stop: ${svc}.service"
      return 0
    fi
  fi

  if _cliproxy_pid_alive; then
    local pid
    pid="$(cat "$CLIPROXY_PID_FILE")"
    kill "$pid" 2>/dev/null || true
    rm -f "$CLIPROXY_PID_FILE"
    _cliproxy_log "stopped (pid $pid)"
  else
    _cliproxy_log "not running"
  fi
}

cliproxy_restart() {
  cliproxy_stop
  cliproxy_start
}

cliproxy_server_status() {
  local mode="${CLIPROXY_RUN_MODE:-direct}"
  [[ "$mode" == "systemd" ]] && mode="background"
  if [[ "$mode" == "background" ]]; then
    if _cliproxy_is_macos; then
      cliproxy_launchd_status
      return $?
    else
      if ! command -v systemctl >/dev/null 2>&1; then
        _cliproxy_log "systemctl not found (systemd unavailable on this OS)"
        return 1
      fi
      local svc="${CLIPROXY_SYSTEMD_SERVICE:-cliproxyapi}"
      systemctl --user status "${svc}.service"
      return 0
    fi
  fi
  if _cliproxy_pid_alive; then
    _cliproxy_log "running (pid $(cat "$CLIPROXY_PID_FILE"))"
  else
    _cliproxy_log "stopped"
  fi
}
