# Core logic for CLIProxyAPI env + model mapping

# Stop if required values are missing
if [[ -z "${CLIPROXY_URL:-}" || -z "${CLIPROXY_KEY:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi

_cliproxy_log() {
  if [[ "${CLIPROXY_LOG_SEP:-1}" != "0" ]]; then
    printf "\n[llmproxy] ------------------------------\n"
  fi
  printf "[llmproxy] %s\n" "$*"
}

# Add thinking suffix if set and not already in the model string
_cliproxy_with_thinking() {
  local model="$1"
  local level="$2"
  if [[ -z "$model" ]]; then
    echo ""
    return
  fi
  if [[ -n "$level" && "$model" != *"("* ]]; then
    echo "${model}(${level})"
  else
    echo "$model"
  fi
}

# Pick the default (Opus) model shown in status
_cliproxy_current_model() {
  if [[ -n "${CLIPROXY_MODEL:-}" ]]; then
    _cliproxy_with_thinking "$CLIPROXY_MODEL" "${CLIPROXY_THINKING_LEVEL:-}"
    return
  fi

  case "${CLIPROXY_PRESET:-}" in
    claude)      echo "${CLIPROXY_CLAUDE_OPUS:-}" ;;
    codex)       _cliproxy_with_thinking "${CLIPROXY_CODEX_OPUS:-}" "${CLIPROXY_CODEX_THINKING_OPUS:-}" ;;
    gemini)      echo "${CLIPROXY_GEMINI_OPUS:-}" ;;
    antigravity) echo "${CLIPROXY_ANTIGRAVITY_MODEL:-}" ;;
    "")         echo "" ;;
    *)           _cliproxy_with_thinking "${CLIPROXY_PRESET}" "${CLIPROXY_THINKING_LEVEL:-}" ;; # allow direct model ID
  esac
}

_cliproxy_status_line() {
  local model
  model="$(_cliproxy_current_model)"
  printf "profile=%s | model=%s" "${CLIPROXY_PROFILE:-}" "${model:-<default>}"
}

_cliproxy_list_models() {
  local json
  json="$(curl -fsS -H "Authorization: Bearer ${CLIPROXY_KEY}" \
    "${CLIPROXY_URL}/v1/models" 2>/dev/null)" || return 1

  python3 - <<'PY' "$json"
import json, sys
try:
    data = json.loads(sys.argv[1])
except Exception:
    sys.exit(1)
models = [m.get("id") for m in data.get("data", []) if isinstance(m, dict)]
for m in sorted(set(filter(None, models))):
    print(m)
PY
}

_cliproxy_server_bin() {
  if [[ -n "${CLIPROXY_BIN:-}" && -x "${CLIPROXY_BIN}" ]]; then
    echo "$CLIPROXY_BIN"
    return 0
  fi
  if command -v cli-proxy-api >/dev/null 2>&1; then
    command -v cli-proxy-api
    return 0
  fi
  if [[ -n "${CLIPROXY_SERVER_DIR:-}" && -x "${CLIPROXY_SERVER_DIR}/cli-proxy-api" ]]; then
    echo "${CLIPROXY_SERVER_DIR}/cli-proxy-api"
    return 0
  fi
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

_cliproxy_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    *) echo "" ;;
  esac
}

cliproxy_run_mode() {
  local mode="${1:-}"
  local persist="${2:-}"
  if [[ -z "$mode" ]]; then
    _cliproxy_log "run mode: ${CLIPROXY_RUN_MODE:-direct}"
    return 0
  fi
  case "$mode" in
    direct|systemd) export CLIPROXY_RUN_MODE="$mode" ;;
    *)
      echo "Usage: cliproxy_run_mode <direct|systemd> [--persist]"
      return 1
      ;;
  esac
  if [[ "$persist" == "--persist" && -n "${CLIPROXY_ENV:-}" && -f "${CLIPROXY_ENV}" ]]; then
    python3 - "$CLIPROXY_ENV" "$mode" <<'PY'
import sys, re
path, mode = sys.argv[1], sys.argv[2]
key = "CLIPROXY_RUN_MODE"
line = f'export {key}="{mode}"\n'
data = open(path, "r", encoding="utf-8").read().splitlines(keepends=True)
out = []
found = False
for l in data:
    if l.startswith(f"export {key}="):
        out.append(line)
        found = True
    else:
        out.append(l)
if not found:
    if out and not out[-1].endswith("\n"):
        out[-1] += "\n"
    out.append("\n" + line if out else line)
open(path, "w", encoding="utf-8").write("".join(out))
PY
  fi
  _cliproxy_log "run mode set: ${CLIPROXY_RUN_MODE}"
}

cliproxy_systemd_install() {
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
WorkingDirectory=${CLIPROXY_SERVER_DIR:-$HOME}
ExecStart=${bin}${config:+ --config ${config}}
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
  local svc="${CLIPROXY_SYSTEMD_SERVICE:-cliproxyapi}"
  systemctl --user enable --now "${svc}.service"
}

cliproxy_start() {
  local mode="${CLIPROXY_RUN_MODE:-direct}"
  if [[ "$mode" == "systemd" ]]; then
    local svc="${CLIPROXY_SYSTEMD_SERVICE:-cliproxyapi}"
    systemctl --user start "${svc}.service"
    _cliproxy_log "systemd start: ${svc}.service"
    return 0
  fi

  local bin config
  bin="$(_cliproxy_server_bin)" || return 1
  config="$(_cliproxy_server_config)"
  mkdir -p "${CLIPROXY_LOG_DIR:-$HOME}"
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
  if [[ "$mode" == "systemd" ]]; then
    local svc="${CLIPROXY_SYSTEMD_SERVICE:-cliproxyapi}"
    systemctl --user stop "${svc}.service"
    _cliproxy_log "systemd stop: ${svc}.service"
    return 0
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
  if [[ "$mode" == "systemd" ]]; then
    local svc="${CLIPROXY_SYSTEMD_SERVICE:-cliproxyapi}"
    systemctl --user status "${svc}.service"
    return 0
  fi
  if _cliproxy_pid_alive; then
    _cliproxy_log "running (pid $(cat "$CLIPROXY_PID_FILE"))"
  else
    _cliproxy_log "stopped"
  fi
}

cliproxy_upgrade() {
  local os arch json url tag tmp archive newbin target running
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(_cliproxy_arch)"
  if [[ "$os" != "linux" ]]; then
    _cliproxy_log "upgrade only supported on linux for now"
    return 1
  fi
  if [[ -z "$arch" ]]; then
    _cliproxy_log "unsupported arch: $(uname -m)"
    return 1
  fi

  json="$(curl -fsS https://api.github.com/repos/router-for-me/CLIProxyAPI/releases/latest)" || {
    _cliproxy_log "failed to fetch latest release"
    return 1
  }

  local out
  out="$(python3 - "$json" "$os" "$arch" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
os, arch = sys.argv[2], sys.argv[3]
tag = data.get("tag_name","")
name = f"{os}_{arch}.tar.gz"
url = ""
for a in data.get("assets", []):
    n = a.get("name","")
    if n.endswith(name):
        url = a.get("browser_download_url","")
        break
print(url)
print(tag)
PY
)" || return 1
  url="$(printf "%s" "$out" | sed -n '1p')"
  tag="$(printf "%s" "$out" | sed -n '2p')"

  if [[ -z "$url" ]]; then
    _cliproxy_log "no release asset found for ${os}_${arch}"
    return 1
  fi

  tmp="$(mktemp -d)" || return 1
  archive="$tmp/cliproxyapi.tar.gz"
  curl -L "$url" -o "$archive" || { _cliproxy_log "download failed"; return 1; }
  tar -xzf "$archive" -C "$tmp" || { _cliproxy_log "extract failed"; return 1; }
  newbin="$(find "$tmp" -type f -name 'cli-proxy-api' | head -n 1)"
  if [[ -z "$newbin" ]]; then
    newbin="$(find "$tmp" -type f -name 'CLIProxyAPI' | head -n 1)"
  fi
  if [[ -z "$newbin" ]]; then
    _cliproxy_log "binary not found in archive"
    return 1
  fi

  target="${CLIPROXY_BIN:-$CLIPROXY_SERVER_DIR/cli-proxy-api}"
  [[ -n "$target" ]] || { _cliproxy_log "set CLIPROXY_BIN"; return 1; }

  running=0
  if [[ "${CLIPROXY_RUN_MODE:-direct}" == "systemd" ]]; then
    systemctl --user is-active --quiet "${CLIPROXY_SYSTEMD_SERVICE:-cliproxyapi}.service" && running=1
  else
    _cliproxy_pid_alive && running=1
  fi

  if (( running )); then
    cliproxy_stop
  fi

  if [[ -f "$target" ]]; then
    cp -f "$target" "${target}.bak-$(date +%Y%m%d%H%M%S)"
  fi
  install -m 755 "$newbin" "$target"
  _cliproxy_log "upgraded to ${tag:-latest} -> ${target}"

  if (( running )); then
    cliproxy_start
  fi
}

cliproxy_backup() {
  local target out
  target="${CLIPROXY_BIN:-$CLIPROXY_SERVER_DIR/cli-proxy-api}"
  if [[ -z "$target" || ! -f "$target" ]]; then
    _cliproxy_log "binary not found; set CLIPROXY_BIN"
    return 1
  fi
  out="${target}.bak-$(date +%Y%m%d%H%M%S)"
  cp -f "$target" "$out"
  _cliproxy_log "backup created: $out"
}

cliproxy_pick_model() {
  local filter="${1:-}"
  local mode="${2:-}"   # optional: codex|claude|gemini to set preset opus
  local picker="${3:-}" # optional: gum|fzf|auto
  local models
  models="$(_cliproxy_list_models)" || {
    _cliproxy_log "failed to fetch /v1/models (is CLIProxyAPI running?)"
    return 1
  }

  if [[ -n "$filter" ]]; then
    # Use extended regex so patterns like "a|b" work as expected.
    models="$(printf "%s\n" "$models" | grep -Ei -- "$filter" || true)"
  fi

  if [[ -z "$models" ]]; then
    _cliproxy_log "no models matched filter: ${filter:-<none>}"
    return 1
  fi

  local picked=""
  if [[ "$picker" == "gum" ]] && command -v gum >/dev/null 2>&1; then
    # Some gum versions don't support --filter, so pre-filter manually.
    local term=""
    if gum choose --help 2>&1 | grep -q -- '--filter'; then
      picked="$(printf "%s\n" "$models" | gum choose --header "$(_cliproxy_status_line)" --filter)" || return
    else
      term="$(gum input --prompt "Filter (optional): " --placeholder "type to narrow")" || return
      if [[ -n "$term" ]]; then
        models="$(printf "%s\n" "$models" | grep -Ei -- "$term" || true)"
      fi
      [[ -n "$models" ]] || return 1
      picked="$(printf "%s\n" "$models" | gum choose --header "$(_cliproxy_status_line)")" || return
    fi
  elif command -v fzf >/dev/null 2>&1; then
    picked="$(printf "%s\n" "$models" | fzf --prompt="Model> " --height=60% --border --no-multi --header="$(_cliproxy_status_line)")" || return
  else
    _cliproxy_log "fzf not found; printing list."
    printf "%s\n" "$models"
    read -r "m?Enter model ID: "
    picked="$m"
  fi

  [[ -n "$picked" ]] || return

  case "$mode" in
    codex)
      export CLIPROXY_CODEX_OPUS="$picked"
      export CLIPROXY_PRESET="codex"
      export CLIPROXY_MODEL=""
      _cliproxy_apply
      _cliproxy_log "codex opus set: $(_cliproxy_current_model)"
      ;;
    claude)
      export CLIPROXY_CLAUDE_OPUS="$picked"
      export CLIPROXY_PRESET="claude"
      export CLIPROXY_MODEL=""
      _cliproxy_apply
      _cliproxy_log "claude opus set: $(_cliproxy_current_model)"
      ;;
    gemini)
      export CLIPROXY_GEMINI_OPUS="$picked"
      export CLIPROXY_PRESET="gemini"
      export CLIPROXY_MODEL=""
      _cliproxy_apply
      _cliproxy_log "gemini opus set: $(_cliproxy_current_model)"
      ;;
    *)
      cliproxy_use "$picked"
      ;;
  esac
}

# Apply environment variables used by Claude Code
_cliproxy_apply() {
  export ANTHROPIC_BASE_URL="$CLIPROXY_URL"
  export ANTHROPIC_AUTH_TOKEN="$CLIPROXY_KEY"
  unset ANTHROPIC_API_KEY
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC:-1}"

  # If a direct model is set, force all tiers to it
  if [[ -n "${CLIPROXY_MODEL:-}" ]]; then
    local direct
    direct="$(_cliproxy_with_thinking "$CLIPROXY_MODEL" "${CLIPROXY_THINKING_LEVEL:-}")"
    export ANTHROPIC_MODEL="$direct"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$direct"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$direct"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$direct"
    return
  fi

  local opus="" sonnet="" haiku="" base=""
  case "${CLIPROXY_PRESET:-}" in
    claude)
      opus="$CLIPROXY_CLAUDE_OPUS"
      sonnet="$CLIPROXY_CLAUDE_SONNET"
      haiku="$CLIPROXY_CLAUDE_HAIKU"
      ;;
    codex)
      opus="$(_cliproxy_with_thinking "${CLIPROXY_CODEX_OPUS:-}" "${CLIPROXY_CODEX_THINKING_OPUS:-}")"
      sonnet="$(_cliproxy_with_thinking "${CLIPROXY_CODEX_SONNET:-}" "${CLIPROXY_CODEX_THINKING_SONNET:-}")"
      haiku="$(_cliproxy_with_thinking "${CLIPROXY_CODEX_HAIKU:-}" "${CLIPROXY_CODEX_THINKING_HAIKU:-}")"
      ;;
    gemini)
      opus="$CLIPROXY_GEMINI_OPUS"
      sonnet="$CLIPROXY_GEMINI_SONNET"
      haiku="$CLIPROXY_GEMINI_HAIKU"
      ;;
    antigravity)
      base="$CLIPROXY_ANTIGRAVITY_MODEL"
      opus="$base"
      sonnet="$base"
      haiku="$base"
      ;;
    "")
      opus=""
      ;;
    *)
      base="$(_cliproxy_with_thinking "${CLIPROXY_PRESET}" "${CLIPROXY_THINKING_LEVEL:-}")"
      opus="$base"
      sonnet="$base"
      haiku="$base"
      ;;
  esac

  # Fill missing tiers from Opus -> Sonnet -> Haiku
  [[ -z "$opus" && -n "$sonnet" ]] && opus="$sonnet"
  [[ -z "$opus" && -n "$haiku" ]] && opus="$haiku"
  [[ -z "$sonnet" && -n "$opus" ]] && sonnet="$opus"
  [[ -z "$haiku" && -n "$sonnet" ]] && haiku="$sonnet"

  if [[ -n "$opus" ]]; then
    export ANTHROPIC_MODEL="$opus"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="$opus"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="$sonnet"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="$haiku"
  else
    unset ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
  fi
}

# Public commands
cliproxy_use() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Usage: cliproxy_use <preset|model-id>"
    echo "Presets: claude | codex | gemini | antigravity"
    return 1
  fi

  case "$name" in
    claude|codex|gemini|antigravity)
      export CLIPROXY_PRESET="$name"
      export CLIPROXY_MODEL=""
      ;;
    *)
      export CLIPROXY_MODEL="$name"
      export CLIPROXY_PRESET=""
      ;;
  esac

  _cliproxy_apply
  _cliproxy_log "model: $(_cliproxy_current_model)"
}

cliproxy_profile() {
  local name="$1"
  if [[ -z "$name" ]]; then
    echo "Usage: cliproxy_profile <local|local2>"
    return 1
  fi
  export CLIPROXY_PROFILE="$name"
  [[ -f "$CLIPROXY_ENV" ]] && source "$CLIPROXY_ENV"
  _cliproxy_apply
  _cliproxy_log "profile: $CLIPROXY_PROFILE"
}

cliproxy_clear() {
  unset CLIPROXY_MODEL
  export CLIPROXY_PRESET="${CLIPROXY_PRESET:-claude}"
  _cliproxy_apply
  _cliproxy_log "model override cleared"
}

cliproxy_status() {
  _cliproxy_log "status"
  printf "  profile : %s\n" "${CLIPROXY_PROFILE:-}"
  printf "  base_url: %s\n" "${CLIPROXY_URL:-}"
  printf "  default : %s\n" "$(_cliproxy_current_model)"
  printf "  opus    : %s\n" "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}"
  printf "  sonnet  : %s\n" "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}"
  printf "  haiku   : %s\n" "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"
}

cliproxy_help() {
  cat <<'EOF'
Usage: llmproxy <command> [args]

Commands:
  ui|menu                 Open interactive menu
  use <preset|model>       Switch preset or set model id
  pick-model [filter]      Pick model from /v1/models
  profile <local|local2>   Switch profile
  status                   Show current env/model status
  clear                    Clear model override

Server:
  start|stop|restart       Control server (direct/systemd)
  server-status            Show server status
  run-mode <direct|systemd> [--persist]
  systemd-install          Install user systemd service
  systemd-enable           Enable + start user systemd service
  upgrade                  Download and replace latest binary
  backup                   Create a timestamped backup of the binary

Notes:
  - "cliproxy" is kept as a legacy alias for llmproxy.
EOF
}

cliproxy() {
  local cmd="${1:-}"
  if (( $# > 0 )); then
    shift
  fi
  case "$cmd" in
    ""|ui|menu) cliproxy_ui ;;
    use) cliproxy_use "$@" ;;
    pick-model) cliproxy_pick_model "$@" ;;
    profile) cliproxy_profile "$@" ;;
    status) cliproxy_status ;;
    clear) cliproxy_clear ;;
    start) cliproxy_start ;;
    stop) cliproxy_stop ;;
    restart) cliproxy_restart ;;
    server-status) cliproxy_server_status ;;
    run-mode) cliproxy_run_mode "$@" ;;
    systemd-install) cliproxy_systemd_install ;;
    systemd-enable) cliproxy_systemd_enable ;;
    upgrade) cliproxy_upgrade ;;
    backup) cliproxy_backup ;;
    help|-h|--help) cliproxy_help ;;
    *)
      echo "Unknown command: $cmd"
      cliproxy_help
      return 1
      ;;
  esac
}

llmproxy_help() {
  cliproxy_help
}

llmproxy() {
  cliproxy "$@"
}
