# Core logic for CLIProxyAPI env + model mapping

_cliproxy_log() {
  if [[ "${CLIPROXY_LOG_SEP:-1}" != "0" ]]; then
    printf "\n[llmproxy] ------------------------------\n"
  fi
  printf "[llmproxy] %s\n" "$*"
}

# Snapshot original Claude env once so we can restore when proxy is disabled.
_llmproxy_snapshot_env() {
  if [[ -n "${_LLMPROXY_SAVED:-}" ]]; then
    return 0
  fi
  export _LLMPROXY_SAVED=1
  export _LLMPROXY_ORIG_ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL-}"
  export _LLMPROXY_ORIG_ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN-}"
  export _LLMPROXY_ORIG_ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY-}"
  export _LLMPROXY_ORIG_ANTHROPIC_MODEL="${ANTHROPIC_MODEL-}"
  export _LLMPROXY_ORIG_ANTHROPIC_DEFAULT_OPUS_MODEL="${ANTHROPIC_DEFAULT_OPUS_MODEL-}"
  export _LLMPROXY_ORIG_ANTHROPIC_DEFAULT_SONNET_MODEL="${ANTHROPIC_DEFAULT_SONNET_MODEL-}"
  export _LLMPROXY_ORIG_ANTHROPIC_DEFAULT_HAIKU_MODEL="${ANTHROPIC_DEFAULT_HAIKU_MODEL-}"
  export _LLMPROXY_ORIG_CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="${CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC-}"
}

_llmproxy_restore_env() {
  if [[ -z "${_LLMPROXY_SAVED:-}" ]]; then
    unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_MODEL
    unset ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
    return 0
  fi
  export ANTHROPIC_BASE_URL="${_LLMPROXY_ORIG_ANTHROPIC_BASE_URL-}"
  export ANTHROPIC_AUTH_TOKEN="${_LLMPROXY_ORIG_ANTHROPIC_AUTH_TOKEN-}"
  export ANTHROPIC_API_KEY="${_LLMPROXY_ORIG_ANTHROPIC_API_KEY-}"
  export ANTHROPIC_MODEL="${_LLMPROXY_ORIG_ANTHROPIC_MODEL-}"
  export ANTHROPIC_DEFAULT_OPUS_MODEL="${_LLMPROXY_ORIG_ANTHROPIC_DEFAULT_OPUS_MODEL-}"
  export ANTHROPIC_DEFAULT_SONNET_MODEL="${_LLMPROXY_ORIG_ANTHROPIC_DEFAULT_SONNET_MODEL-}"
  export ANTHROPIC_DEFAULT_HAIKU_MODEL="${_LLMPROXY_ORIG_ANTHROPIC_DEFAULT_HAIKU_MODEL-}"
  export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC="${_LLMPROXY_ORIG_CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC-}"
}

_llmproxy_clear_proxy_env() {
  if [[ "${ANTHROPIC_BASE_URL-}" == "${CLIPROXY_URL-}" ]]; then
    unset ANTHROPIC_BASE_URL
  fi
  if [[ "${ANTHROPIC_AUTH_TOKEN-}" == "${CLIPROXY_KEY-}" ]]; then
    unset ANTHROPIC_AUTH_TOKEN
  fi
  # If proxy vars were in effect, also clear model overrides.
  if [[ -z "${ANTHROPIC_BASE_URL-}" && -z "${ANTHROPIC_AUTH_TOKEN-}" ]]; then
    unset ANTHROPIC_MODEL ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL ANTHROPIC_DEFAULT_HAIKU_MODEL
  fi
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
  if [[ -z "${CLIPROXY_URL:-}" || -z "${CLIPROXY_KEY:-}" ]]; then
    _cliproxy_log "CLIPROXY_URL/CLIPROXY_KEY not set"
    return 1
  fi
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

_llmproxy_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

_llmproxy_path_has_local_bin() {
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) return 0 ;;
    *) return 1 ;;
  esac
}

_llmproxy_default_rc() {
  if [[ -n "${LLMPROXY_RC:-}" ]]; then
    echo "$LLMPROXY_RC"
    return
  fi
  if [[ -n "${SHELL:-}" && "${SHELL}" == *"zsh" ]]; then
    echo "$HOME/.zshrc"
    return
  fi
  if [[ -f "$HOME/.zshrc" ]]; then
    echo "$HOME/.zshrc"
    return
  fi
  echo "$HOME/.bashrc"
}

llmproxy_install() {
  local rc line start end bin_dir src link
  rc="${1:-$(_llmproxy_default_rc)}"
  start="# >>> llmproxy >>>"
  end="# <<< llmproxy <<<"
  line='export PATH="$HOME/.local/bin:$PATH"'
  local line2='if command -v llmproxy >/dev/null 2>&1; then eval "$(llmproxy init)"; fi'

  bin_dir="$HOME/.local/bin"
  src="${CLIPROXY_HOME:-$HOME/cliproxyapi/llmproxy-config}/llmproxy"
  link="$bin_dir/llmproxy"
  mkdir -p "$bin_dir"
  if [[ -f "$src" ]]; then
    ln -sf "$src" "$link"
  fi

  python3 - "$rc" "$start" "$end" "$line" "$line2" <<'PY'
import sys
rc, start, end, line, line2 = sys.argv[1:]
try:
    data = open(rc, "r", encoding="utf-8").read().splitlines(keepends=True)
except FileNotFoundError:
    data = []

out = []
in_block = False
found = False
for l in data:
    if l.strip() == start:
        in_block = True
        found = True
        out.append(start + "\n")
        out.append(line + "\n")
        out.append(line2 + "\n")
        out.append(end + "\n")
        continue
    if in_block:
        if l.strip() == end:
            in_block = False
        continue
    out.append(l)

if not found:
    if out and not out[-1].endswith("\n"):
        out[-1] += "\n"
    if out and out[-1].strip():
        out.append("\n")
    out.append(start + "\n")
    out.append(line + "\n")
    out.append(line2 + "\n")
    out.append(end + "\n")

open(rc, "w", encoding="utf-8").write("".join(out))
print(rc)
PY

  _cliproxy_log "installed auto-source in: ${rc}"
}

llmproxy_fix() {
  local os missing=()
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  for cmd in curl python3 fzf; do
    if ! _llmproxy_has_cmd "$cmd"; then
      missing+=("$cmd")
    fi
  done
  if (( ${#missing[@]} == 0 )); then
    _cliproxy_log "no missing deps"
    return 0
  fi

  _cliproxy_log "installing: ${missing[*]}"
  if [[ "$os" == "linux" ]]; then
    if _llmproxy_has_cmd apt; then
      sudo apt update && sudo apt install -y curl python3 fzf
      return $?
    fi
    _cliproxy_log "apt not found; install manually: ${missing[*]}"
    return 1
  fi
  if [[ "$os" == "darwin" ]]; then
    if _llmproxy_has_cmd brew; then
      brew install curl python fzf
      return $?
    fi
    _cliproxy_log "brew not found; install Homebrew first"
    return 1
  fi

  _cliproxy_log "unsupported OS; install manually: ${missing[*]}"
  return 1
}

llmproxy_doctor() {
  _cliproxy_log "doctor"
  local os arch missing=0
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(_cliproxy_arch)"
  printf "  os       : %s\n" "$os"
  printf "  arch     : %s\n" "${arch:-unknown}"
  printf "  mode     : %s\n" "${LLMPROXY_MODE:-proxy}"
  printf "  run-mode : %s\n" "${CLIPROXY_RUN_MODE:-direct}"
  if _llmproxy_path_has_local_bin; then
    printf "  path     : ok (~/.local/bin)\n"
  else
    printf "  path     : missing ~/.local/bin\n"
    missing=1
  fi

  for cmd in zsh curl python3; do
    if _llmproxy_has_cmd "$cmd"; then
      printf "  %s     : ok\n" "$cmd"
    else
      printf "  %s     : missing\n" "$cmd"
      missing=1
    fi
  done
  if _llmproxy_has_cmd fzf; then
    printf "  fzf     : ok (UI picker)\n"
  else
    printf "  fzf     : missing (text menu only)\n"
  fi

  if [[ -n "${CLIPROXY_URL:-}" && -n "${CLIPROXY_KEY:-}" ]]; then
    if curl -fsS -H "Authorization: Bearer ${CLIPROXY_KEY}" \
      "${CLIPROXY_URL}/v1/models" >/dev/null 2>&1; then
      printf "  server  : reachable (%s)\n" "$CLIPROXY_URL"
    else
      printf "  server  : not reachable (%s)\n" "$CLIPROXY_URL"
    fi
  else
    printf "  server  : CLIPROXY_URL/KEY not set\n"
  fi

  if [[ "$os" == "darwin" ]]; then
    printf "  systemd : not available (macOS)\n"
  else
    if _llmproxy_has_cmd systemctl; then
      printf "  systemd : available\n"
    else
      printf "  systemd : not available\n"
    fi
  fi

  if (( missing )); then
    _cliproxy_log "missing prerequisites detected (see README)"
  fi
}

llmproxy_setup() {
  local home env example base_url key run_mode
  home="${CLIPROXY_HOME:-$HOME/cliproxyapi/llmproxy-config}"
  env="${CLIPROXY_ENV:-$home/.llmproxy.env}"
  example="$home/.llmproxy.env.example"
  llmproxy_doctor
  local ans
  if ! _llmproxy_path_has_local_bin; then
    export PATH="$HOME/.local/bin:$PATH"
    _cliproxy_log "added ~/.local/bin to PATH for this session"
  fi
  read -r "ans?Auto-fix missing deps? (y/N): "
  if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
    llmproxy_fix
  fi
  if [[ ! -f "$env" ]]; then
    if [[ -f "$example" ]]; then
      cp "$example" "$env"
      _cliproxy_log "created $env from template"
    else
      _cliproxy_log "template not found: $example"
      return 1
    fi
  fi

  local proxy_mode preset rc_path
  read -r "base_url?Base URL [${CLIPROXY_URL_LOCAL:-http://127.0.0.1:8317}]: "
  base_url="${base_url:-${CLIPROXY_URL_LOCAL:-http://127.0.0.1:8317}}"
  read -r "key?API key (CLIPROXY_KEY_LOCAL) [leave empty to keep]: "
  read -r "run_mode?Run mode (direct/systemd) [${CLIPROXY_RUN_MODE:-direct}]: "
  run_mode="${run_mode:-${CLIPROXY_RUN_MODE:-direct}}"
  read -r "proxy_mode?Proxy mode (proxy/direct) [${LLMPROXY_MODE:-proxy}]: "
  proxy_mode="${proxy_mode:-${LLMPROXY_MODE:-proxy}}"
  read -r "preset?Preset (claude/codex/gemini/antigravity) [${CLIPROXY_PRESET:-claude}]: "
  preset="${preset:-${CLIPROXY_PRESET:-claude}}"

  python3 - "$env" "$base_url" "$key" "$run_mode" "$proxy_mode" "$preset" <<'PY'
import sys, re
path, base_url, key, run_mode, proxy_mode, preset = sys.argv[1:7]
data = open(path, "r", encoding="utf-8").read().splitlines(keepends=True)
def set_kv(lines, k, v):
    out = []
    found = False
    for l in lines:
        if l.startswith(f'export {k}='):
            out.append(f'export {k}="{v}"\\n')
            found = True
        else:
            out.append(l)
    if not found:
        if out and not out[-1].endswith("\\n"):
            out[-1] += "\\n"
        out.append(f'export {k}="{v}"\\n')
    return out

data = set_kv(data, "CLIPROXY_URL_LOCAL", base_url)
if key:
    data = set_kv(data, "CLIPROXY_KEY_LOCAL", key)
data = set_kv(data, "CLIPROXY_RUN_MODE", run_mode)
data = set_kv(data, "LLMPROXY_MODE", proxy_mode)
data = set_kv(data, "CLIPROXY_PRESET", preset)
open(path, "w", encoding="utf-8").write("".join(data))
PY

  read -r "ans?Install auto-source into shell rc? (Y/n): "
  if [[ -z "$ans" || "$ans" == "y" || "$ans" == "Y" ]]; then
    rc_path="$(_llmproxy_default_rc)"
    llmproxy_install "$rc_path"
  fi

  _cliproxy_log "setup complete; reload shell to apply"
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
  if ! command -v systemctl >/dev/null 2>&1; then
    _cliproxy_log "systemctl not found (systemd unavailable on this OS)"
    return 1
  fi
  local svc="${CLIPROXY_SYSTEMD_SERVICE:-cliproxyapi}"
  systemctl --user enable --now "${svc}.service"
}

cliproxy_start() {
  local mode="${CLIPROXY_RUN_MODE:-direct}"
  if [[ "$mode" == "systemd" ]]; then
    if ! command -v systemctl >/dev/null 2>&1; then
      _cliproxy_log "systemctl not found (systemd unavailable on this OS)"
      return 1
    fi
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
    if ! command -v systemctl >/dev/null 2>&1; then
      _cliproxy_log "systemctl not found (systemd unavailable on this OS)"
      return 1
    fi
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
    if ! command -v systemctl >/dev/null 2>&1; then
      _cliproxy_log "systemctl not found (systemd unavailable on this OS)"
      return 1
    fi
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
  if [[ "$os" != "linux" && "$os" != "darwin" ]]; then
    _cliproxy_log "upgrade only supported on linux/macos for now"
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
  _llmproxy_snapshot_env
  if [[ "${LLMPROXY_MODE:-proxy}" == "direct" ]]; then
    _llmproxy_restore_env
    return
  fi

  if [[ -z "${CLIPROXY_URL:-}" || -z "${CLIPROXY_KEY:-}" ]]; then
    _cliproxy_log "CLIPROXY_URL/CLIPROXY_KEY not set (proxy disabled)"
    return 1
  fi

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
llmproxy_on() {
  export LLMPROXY_MODE="proxy"
  _cliproxy_apply
  _cliproxy_log "proxy enabled (Claude Code -> CLIProxyAPI)"
}

llmproxy_off() {
  export LLMPROXY_MODE="direct"
  _llmproxy_restore_env
  _llmproxy_clear_proxy_env
  _cliproxy_log "proxy disabled (use official Claude)"
}

llmproxy_toggle() {
  if [[ "${LLMPROXY_MODE:-proxy}" == "direct" ]]; then
    llmproxy_on
  else
    llmproxy_off
  fi
}

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
  on|off|toggle            Enable/disable proxy env (Claude official vs proxy)
  setup                    Wizard: env + auto-source + deps
  install [rcfile]         Add auto-source to shell rc
  fix                      Auto-install missing deps
  doctor                   Check environment and dependencies
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
    on) llmproxy_on ;;
    off) llmproxy_off ;;
    toggle) llmproxy_toggle ;;
    setup) llmproxy_setup ;;
    install) llmproxy_install "$@" ;;
    fix) llmproxy_fix ;;
    doctor) llmproxy_doctor ;;
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
