# Setup prompt helpers + CLIProxyAPI config generation

_llmproxy_prompt_yes_no() {
  local prompt="$1"
  local default="$2"
  local answer
  local suffix=""
  case "$default" in
    y|Y) suffix="(Y/n)" ;;
    n|N) suffix="(y/N)" ;;
    *) suffix="(y/n)" ;;
  esac
  read -r "answer?${prompt} ${suffix}: "
  if [[ -z "$answer" ]]; then
    answer="$default"
  fi
  [[ "$answer" == "y" || "$answer" == "Y" ]]
}

_llmproxy_generate_secret_key() {
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(32))
PY
    return
  fi
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -base64 32
    return
  fi
  _cliproxy_log "cannot generate secret key (missing python3/openssl)"
  return 1
}

_llmproxy_write_config_yaml() {
  local path="$1"
  local host="$2"
  local port="$3"
  local auth_dir="$4"
  local api_key="$5"
  local web_ui_enabled="$6"

  if [[ -z "$api_key" ]]; then
    api_key="sk-REPLACE_ME"
  fi
  mkdir -p "$(dirname "$path")"

  local allow_remote="false"
  local secret_key=""
  local disable_panel="false"

  if [[ "$web_ui_enabled" == "true" ]]; then
    if ! secret_key="$(_llmproxy_generate_secret_key)"; then
      _cliproxy_log "disabling Web UI (no secure secret generator available)"
      disable_panel="true"
    fi
  else
    disable_panel="true"
  fi

  cat > "$path" <<EOF
host: "${host}"
port: ${port}
auth-dir: "${auth_dir}"
api-keys:
  - "${api_key}"
remote-management:
  allow-remote: ${allow_remote}
  secret-key: "${secret_key}"
  disable-control-panel: ${disable_panel}
  panel-github-repository: "https://github.com/router-for-me/Cli-Proxy-API-Management-Center"
logging-to-file: false
logs-max-total-size-mb: 0
usage-statistics-enabled: false
EOF

  chmod 600 "$path" 2>/dev/null || true

  if [[ "$web_ui_enabled" == "true" ]]; then
    _cliproxy_log "Web UI enabled: secret key generated"
  else
    _cliproxy_log "Web UI disabled (control panel off)"
  fi
}
