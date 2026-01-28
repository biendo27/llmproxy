# systemd integration (Linux)

cliproxy_systemd_install() {
  if ! command -v systemctl >/dev/null 2>&1; then
    _cliproxy_log "systemctl not found (systemd unavailable on this OS)"
    return 1
  fi
  local bin config unit_dir unit svc
  bin="$(_cliproxy_server_bin)" || return 1
  config="$(_cliproxy_server_config)"
  svc="${CLIPROXY_SYSTEMD_SERVICE:-cliproxyapi}"
  unit_dir="$HOME/.config/systemd/user"
  unit="$unit_dir/${svc}.service"
  mkdir -p "$unit_dir"

  cat > "$unit" <<EOF
[Unit]
Description=CLIProxyAPI Service
After=network.target

[Service]
Type=simple
WorkingDirectory="${CLIPROXY_SERVER_DIR:-$HOME}"
ExecStart="${bin}"${config:+ --config "${config}"}
Restart=always
RestartSec=5
Environment=HOME=${HOME}

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  _cliproxy_log "systemd service installed: $unit"
}

cliproxy_systemd_enable() {
  if ! command -v systemctl >/dev/null 2>&1; then
    _cliproxy_log "systemctl not found (systemd unavailable on this OS)"
    return 1
  fi
  local svc="${CLIPROXY_SYSTEMD_SERVICE:-cliproxyapi}"
  systemctl --user enable --now "${svc}.service"
}
