# Core logic for CLIProxyAPI env + model mapping

LLMPROXY_HOME_DEFAULT="${CLIPROXY_HOME:-$HOME/cliproxyapi/llmproxy-config}"
LLMPROXY_LIB="${LLMPROXY_HOME_DEFAULT}/.llmproxy.lib.zsh"
LLMPROXY_APPLY="${LLMPROXY_HOME_DEFAULT}/.llmproxy.apply.zsh"
if [[ -f "$LLMPROXY_LIB" ]]; then
  source "$LLMPROXY_LIB"
else
  printf "[llmproxy] missing helper library: %s\n" "$LLMPROXY_LIB" >&2
fi
if [[ -f "$LLMPROXY_APPLY" ]]; then
  source "$LLMPROXY_APPLY"
else
  printf "[llmproxy] missing apply library: %s\n" "$LLMPROXY_APPLY" >&2
fi

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

llmproxy_env() {
  _cliproxy_log "env"
  printf "  mode       : %s\n" "${LLMPROXY_MODE:-proxy}"
  printf "  run-mode   : %s\n" "${CLIPROXY_RUN_MODE:-direct}"
  printf "  base_url   : %s\n" "${CLIPROXY_URL:-}"
  printf "  key        : %s\n" "$(_llmproxy_mask "${CLIPROXY_KEY:-}")"
  printf "  model      : %s\n" "$(_cliproxy_current_model)"
  printf "  ANTHROPIC_BASE_URL : %s\n" "${ANTHROPIC_BASE_URL-}"
  printf "  ANTHROPIC_AUTH_TOKEN : %s\n" "$(_llmproxy_mask "${ANTHROPIC_AUTH_TOKEN-}")"
  printf "  ANTHROPIC_MODEL : %s\n" "${ANTHROPIC_MODEL-}"
}

llmproxy_whoami() {
  _cliproxy_log "auth check"
  if [[ -z "${CLIPROXY_URL:-}" || -z "${CLIPROXY_KEY:-}" ]]; then
    _cliproxy_log "CLIPROXY_URL/CLIPROXY_KEY not set"
    return 1
  fi
  local json
  json="$(curl -fsS -H "Authorization: Bearer ${CLIPROXY_KEY}" \
    "${CLIPROXY_URL}/v1/models" 2>/dev/null)" || {
    _cliproxy_log "auth failed (cannot reach /v1/models)"
    return 1
  }
  python3 - <<'PY' "$json" "$(_cliproxy_current_model)"
import json, sys
data = json.loads(sys.argv[1])
cur = sys.argv[2]
models = [m.get("id") for m in data.get("data", []) if isinstance(m, dict)]
models = [m for m in models if m]
print(f"  models    : {len(models)} available")
if cur:
    print(f"  current  : {cur} ({'ok' if cur in models else 'not found'})")
PY
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
  local mode="${2:-}"   # optional: codex|claude|gemini to set preset tiers
  local picker="${3:-}" # optional: gum|fzf|auto
  local models default_label
  default_label="Default (keep current)"
  models="$(_cliproxy_list_models)" || {
    _cliproxy_log "failed to fetch /v1/models (is CLIProxyAPI running?)"
    return 1
  }

  if [[ -n "$filter" ]]; then
    # Use extended regex so patterns like "a|b" work as expected.
    models="$(printf "%s\n" "$models" | grep -Ei -- "$filter" || true)"
  fi

  if [[ -z "$models" ]]; then
    _cliproxy_log "no models matched filter: ${filter:-<none>} (default only)"
    models=""
  fi

  _cliproxy_pick_from_list() {
    local list="$1"
    local header="$2"
    local picked=""
    if [[ "$picker" == "gum" ]] && command -v gum >/dev/null 2>&1; then
      local term=""
      if gum choose --help 2>&1 | grep -q -- '--filter'; then
        picked="$(printf "%s\n" "$list" | gum choose --header "$header" --filter)" || return 1
      else
        term="$(gum input --prompt "Filter (optional): " --placeholder "type to narrow")" || return 1
        if [[ -n "$term" ]]; then
          list="$(printf "%s\n" "$list" | grep -Ei -- "$term" || true)"
          if ! printf "%s\n" "$list" | grep -Fxq -- "$default_label"; then
            list="$(printf "%s\n%s\n" "$default_label" "$list")"
          fi
        fi
        [[ -n "$list" ]] || list="$default_label"
        picked="$(printf "%s\n" "$list" | gum choose --header "$header")" || return 1
      fi
    elif command -v fzf >/dev/null 2>&1; then
      picked="$(printf "%s\n" "$list" | fzf --prompt="Model> " --height=60% --border --no-multi --header="$header")" || return 1
    else
      _cliproxy_log "fzf not found; printing list."
      printf "%s\n" "$list"
      read -r "m?Enter model ID (empty = keep current): "
      picked="$m"
    fi
    printf "%s" "$picked"
  }

  case "$mode" in
    codex|claude|gemini)
      _llmproxy_sync_preset_models "$mode"
      local picked current list header changed=0
      local tiers=("opus" "sonnet" "haiku")
      for tier in "${tiers[@]}"; do
        case "$mode:$tier" in
          codex:opus)
            current="$(_cliproxy_with_thinking "${CLIPROXY_CODEX_OPUS:-}" "${CLIPROXY_CODEX_THINKING_OPUS:-}")"
            ;;
          codex:sonnet)
            current="$(_cliproxy_with_thinking "${CLIPROXY_CODEX_SONNET:-}" "${CLIPROXY_CODEX_THINKING_SONNET:-}")"
            ;;
          codex:haiku)
            current="$(_cliproxy_with_thinking "${CLIPROXY_CODEX_HAIKU:-}" "${CLIPROXY_CODEX_THINKING_HAIKU:-}")"
            ;;
          claude:opus) current="${CLIPROXY_CLAUDE_OPUS:-}" ;;
          claude:sonnet) current="${CLIPROXY_CLAUDE_SONNET:-}" ;;
          claude:haiku) current="${CLIPROXY_CLAUDE_HAIKU:-}" ;;
          gemini:opus) current="${CLIPROXY_GEMINI_OPUS:-}" ;;
          gemini:sonnet) current="${CLIPROXY_GEMINI_SONNET:-}" ;;
          gemini:haiku) current="${CLIPROXY_GEMINI_HAIKU:-}" ;;
          *) current="" ;;
        esac

        list="$default_label"
        if [[ -n "$models" ]]; then
          list="$(printf "%s\n%s\n" "$default_label" "$models")"
        fi
        header="Override ${mode} ${tier} model (current: ${current:-<unset>})"
        picked="$(_cliproxy_pick_from_list "$list" "$header")" || { _cliproxy_log "skip ${tier} (cancelled)"; continue; }
        [[ -z "$picked" || "$picked" == "$default_label" ]] && continue

        case "$mode:$tier" in
          codex:opus) export CLIPROXY_CODEX_OPUS="$picked" ;;
          codex:sonnet) export CLIPROXY_CODEX_SONNET="$picked" ;;
          codex:haiku) export CLIPROXY_CODEX_HAIKU="$picked" ;;
          claude:opus) export CLIPROXY_CLAUDE_OPUS="$picked" ;;
          claude:sonnet) export CLIPROXY_CLAUDE_SONNET="$picked" ;;
          claude:haiku) export CLIPROXY_CLAUDE_HAIKU="$picked" ;;
          gemini:opus) export CLIPROXY_GEMINI_OPUS="$picked" ;;
          gemini:sonnet) export CLIPROXY_GEMINI_SONNET="$picked" ;;
          gemini:haiku) export CLIPROXY_GEMINI_HAIKU="$picked" ;;
        esac
        changed=1
      done

      export CLIPROXY_PRESET="$mode"
      export CLIPROXY_MODEL=""
      _cliproxy_apply
      if (( changed )); then
        _cliproxy_log "$mode tiers updated"
      else
        _cliproxy_log "kept current $mode preset"
      fi
      ;;
    *)
      local picked=""
      local list="$default_label"
      if [[ -n "$models" ]]; then
        list="$(printf "%s\n%s\n" "$default_label" "$models")"
      fi
      picked="$(_cliproxy_pick_from_list "$list" "$(_cliproxy_status_line)")" || return
      [[ -n "$picked" && "$picked" != "$default_label" ]] || { _cliproxy_log "kept current preset/model"; return 0; }
      cliproxy_use "$picked"
      ;;
  esac
}

# Apply environment variables used by Claude Code

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
      _llmproxy_sync_preset_models "$name"
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
  local preset="${CLIPROXY_PRESET:-}"
  local opus="${ANTHROPIC_DEFAULT_OPUS_MODEL:-}"
  local sonnet="${ANTHROPIC_DEFAULT_SONNET_MODEL:-}"
  local haiku="${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}"

  # When proxy is off (or apply was skipped), fall back to preset/exported values
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

  # Fill missing tiers for display
  [[ -z "$opus" && -n "$sonnet" ]] && opus="$sonnet"
  [[ -z "$opus" && -n "$haiku" ]] && opus="$haiku"
  [[ -z "$sonnet" && -n "$opus" ]] && sonnet="$opus"
  [[ -z "$haiku" && -n "$sonnet" ]] && haiku="$sonnet"

  printf "  profile : %s\n" "${CLIPROXY_PROFILE:-}"
  printf "  base_url: %s\n" "${CLIPROXY_URL:-}"
  printf "  default : %s\n" "$(_cliproxy_current_model)"
  printf "  opus    : %s\n" "$opus"
  printf "  sonnet  : %s\n" "$sonnet"
  printf "  haiku   : %s\n" "$haiku"
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
  env                      Show current env + mode
  whoami                   Check auth via /v1/models
  sync-models <preset>     Sync preset models from /v1/models
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
