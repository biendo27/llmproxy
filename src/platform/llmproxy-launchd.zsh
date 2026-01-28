# launchd integration (macOS)

_cliproxy_launchd_label() {
  echo "${CLIPROXY_LAUNCHD_LABEL:-com.cliproxyapi}"
}

_cliproxy_launchd_plist_path() {
  echo "$HOME/Library/LaunchAgents/$(_cliproxy_launchd_label).plist"
}

cliproxy_launchd_install() {
  if ! _cliproxy_is_macos; then
    _cliproxy_log "launchd only available on macOS"
    return 1
  fi

  local bin config plist label log_dir
  bin="$(_cliproxy_server_bin)" || return 1
  config="$(_cliproxy_server_config)"
  label="$(_cliproxy_launchd_label)"
  plist="$(_cliproxy_launchd_plist_path)"
  log_dir="${CLIPROXY_LOG_DIR:-$HOME}"

  mkdir -p "$HOME/Library/LaunchAgents"
  mkdir -p "$log_dir"

  local prog_args="<string>${bin}</string>"
  if [[ -n "$config" ]]; then
    prog_args="${prog_args}
        <string>--config</string>
        <string>${config}</string>"
  fi

  cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${label}</string>
    <key>ProgramArguments</key>
    <array>
        ${prog_args}
    </array>
    <key>WorkingDirectory</key>
    <string>${CLIPROXY_SERVER_DIR:-$HOME}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${log_dir}/cliproxyapi.out.log</string>
    <key>StandardErrorPath</key>
    <string>${log_dir}/cliproxyapi.err.log</string>
</dict>
</plist>
EOF

  _cliproxy_log "launchd plist installed: $plist"
}

cliproxy_launchd_enable() {
  if ! _cliproxy_is_macos; then
    _cliproxy_log "launchd only available on macOS"
    return 1
  fi

  local plist label
  plist="$(_cliproxy_launchd_plist_path)"
  label="$(_cliproxy_launchd_label)"

  if [[ ! -f "$plist" ]]; then
    _cliproxy_log "plist not found; run launchd-install first"
    return 1
  fi

  launchctl unload "$plist" 2>/dev/null || true
  launchctl load -w "$plist"
  _cliproxy_log "launchd loaded: $label"
}

cliproxy_launchd_start() {
  if ! _cliproxy_is_macos; then
    _cliproxy_log "launchd only available on macOS"
    return 1
  fi

  local plist label
  plist="$(_cliproxy_launchd_plist_path)"
  label="$(_cliproxy_launchd_label)"

  if [[ ! -f "$plist" ]]; then
    _cliproxy_log "plist not found; run launchd-install first"
    return 1
  fi

  if launchctl list 2>/dev/null | grep -q "$label"; then
    _cliproxy_log "launchd already running: $label"
    return 0
  fi

  launchctl load -w "$plist"
  _cliproxy_log "launchd started: $label"
}

cliproxy_launchd_stop() {
  if ! _cliproxy_is_macos; then
    _cliproxy_log "launchd only available on macOS"
    return 1
  fi

  local plist label
  plist="$(_cliproxy_launchd_plist_path)"
  label="$(_cliproxy_launchd_label)"

  if [[ ! -f "$plist" ]]; then
    _cliproxy_log "plist not found"
    return 1
  fi

  launchctl unload "$plist" 2>/dev/null || true
  _cliproxy_log "launchd stopped: $label"
}

cliproxy_launchd_status() {
  if ! _cliproxy_is_macos; then
    _cliproxy_log "launchd only available on macOS"
    return 1
  fi

  local label
  label="$(_cliproxy_launchd_label)"

  if launchctl list 2>/dev/null | grep -q "$label"; then
    local info
    info="$(launchctl list "$label" 2>/dev/null)" || true
    _cliproxy_log "launchd running: $label"
    if [[ -n "$info" ]]; then
      echo "$info"
    fi
  else
    _cliproxy_log "launchd not running: $label"
  fi
}
