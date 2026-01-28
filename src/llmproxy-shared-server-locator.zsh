# CLIProxyAPI server binary/config resolution

_cliproxy_server_bin() {
  local candidate prefix found
  if [[ -n "${CLIPROXY_BIN:-}" && -x "${CLIPROXY_BIN}" ]]; then
    echo "$CLIPROXY_BIN"
    return 0
  fi
  for candidate in cli-proxy-api CLIProxyAPI cliproxyapi; do
    if command -v "$candidate" >/dev/null 2>&1; then
      found="$(command -v "$candidate")"
      [[ -n "$found" ]] && export CLIPROXY_BIN="$found"
      echo "$found"
      return 0
    fi
  done
  if command -v where >/dev/null 2>&1; then
    for candidate in cli-proxy-api CLIProxyAPI cliproxyapi; do
      found="$(where "$candidate" 2>/dev/null | tr ' ' '\n' | sed -n 's#^\(/.*\)#\1#p' | head -n 1)"
      if [[ -n "$found" && -x "$found" ]]; then
        export CLIPROXY_BIN="$found"
        echo "$found"
        return 0
      fi
    done
  fi
  if [[ -n "${CLIPROXY_SERVER_DIR:-}" ]]; then
    for candidate in cli-proxy-api CLIProxyAPI cliproxyapi; do
      if [[ -x "${CLIPROXY_SERVER_DIR}/$candidate" ]]; then
        found="${CLIPROXY_SERVER_DIR}/$candidate"
        export CLIPROXY_BIN="$found"
        echo "$found"
        return 0
      fi
    done
  fi
  for prefix in /opt/homebrew/bin /usr/local/bin; do
    for candidate in cli-proxy-api CLIProxyAPI cliproxyapi; do
      if [[ -x "${prefix}/$candidate" ]]; then
        found="${prefix}/$candidate"
        export CLIPROXY_BIN="$found"
        echo "$found"
        return 0
      fi
    done
  done
  _cliproxy_log "cli-proxy-api not found; set CLIPROXY_BIN"
  return 1
}

_cliproxy_server_config() {
  if [[ -n "${CLIPROXY_CONFIG:-}" && -f "${CLIPROXY_CONFIG}" ]]; then
    echo "$CLIPROXY_CONFIG"
    return 0
  fi
  if [[ -n "${CLIPROXY_SERVER_DIR:-}" && -f "${CLIPROXY_SERVER_DIR}/config.yaml" ]]; then
    echo "${CLIPROXY_SERVER_DIR}/config.yaml"
    return 0
  fi
  echo ""
}

_cliproxy_pid_alive() {
  local pid
  [[ -n "${CLIPROXY_PID_FILE:-}" ]] || return 1
  pid="$(cat "$CLIPROXY_PID_FILE" 2>/dev/null)" || return 1
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}
