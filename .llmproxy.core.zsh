# Core logic for CLIProxyAPI env + model mapping

# CLIPROXY_HOME is set by .llmproxy.zsh bootstrap before sourcing this file
LLMPROXY_HOME_DEFAULT="${CLIPROXY_HOME:-}"
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
  local rc start end src
  rc="${1:-$(_llmproxy_default_rc)}"
  start="# >>> llmproxy >>>"
  end="# <<< llmproxy <<<"
  src="${CLIPROXY_HOME}"

  if [[ -z "$src" ]]; then
    _cliproxy_log "CLIPROXY_HOME not set; run from repo or set CLIPROXY_HOME"
    return 1
  fi

  # Replace $HOME prefix for portability (works on Linux /home/user and macOS /Users/user)
  local portable_src="$src"
  if [[ "$src" == "$HOME"* ]]; then
    portable_src="\$HOME${src#$HOME}"
  fi
  local export_line="export CLIPROXY_HOME=\"${portable_src}\""
  local source_line='[[ -f "$CLIPROXY_HOME/.llmproxy.zsh" ]] && source "$CLIPROXY_HOME/.llmproxy.zsh"'

  python3 - "$rc" "$start" "$end" "$export_line" "$source_line" <<'PY'
import sys
rc, start, end, export_line, source_line = sys.argv[1:]
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
        out.append(export_line + "\n")
        out.append(source_line + "\n")
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
    out.append(export_line + "\n")
    out.append(source_line + "\n")
    out.append(end + "\n")

open(rc, "w", encoding="utf-8").write("".join(out))
print(rc)
PY

  _cliproxy_log "installed auto-source in: ${rc}"
}

llmproxy_init() {
  local home src
  home="${CLIPROXY_HOME:-$LLMPROXY_HOME_DEFAULT}"
  src="$home/.llmproxy.zsh"
  [[ -f "$src" ]] || return 1
  echo "source \"$src\""
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
  setopt local_options
  unsetopt xtrace verbose
  local os arch missing=0
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(_cliproxy_arch)"
  local w=10
  _llmproxy_kv "os" "$os" "$w"
  _llmproxy_kv "arch" "${arch:-unknown}" "$w"
  _llmproxy_kv "mode" "${LLMPROXY_MODE:-proxy}" "$w"
  _llmproxy_kv "run-mode" "${CLIPROXY_RUN_MODE:-direct}" "$w"
  _llmproxy_kv "home" "${CLIPROXY_HOME:-<not set>}" "$w"

  for cmd in zsh curl python3; do
    if _llmproxy_has_cmd "$cmd"; then
      _llmproxy_kv "$cmd" "ok" "$w"
    else
      _llmproxy_kv "$cmd" "missing" "$w"
      missing=1
    fi
  done
  if _llmproxy_has_cmd fzf; then
    _llmproxy_kv "fzf" "ok (UI picker)" "$w"
  else
    _llmproxy_kv "fzf" "missing (text menu only)" "$w"
  fi

  if [[ -n "${CLIPROXY_URL:-}" && -n "${CLIPROXY_KEY:-}" ]]; then
    if curl -fsS -H "Authorization: Bearer ${CLIPROXY_KEY}" \
      "${CLIPROXY_URL}/v1/models" >/dev/null 2>&1; then
      _llmproxy_kv "server" "reachable (${CLIPROXY_URL})" "$w"
    else
      _llmproxy_kv "server" "not reachable (${CLIPROXY_URL})" "$w"
    fi
  else
    _llmproxy_kv "server" "CLIPROXY_URL/KEY not set" "$w"
  fi

  if [[ "$os" == "darwin" ]]; then
    _llmproxy_kv "systemd" "not available (macOS)" "$w"
  else
    if _llmproxy_has_cmd systemctl; then
      _llmproxy_kv "systemd" "available" "$w"
    else
      _llmproxy_kv "systemd" "not available" "$w"
    fi
  fi

  if (( missing )); then
    _cliproxy_log "missing prerequisites detected (see README)"
  fi
}

llmproxy_env() {
  _cliproxy_log "env"
  setopt local_options
  unsetopt xtrace verbose
  local w=22
  _llmproxy_kv "mode" "${LLMPROXY_MODE:-proxy}" "$w"
  _llmproxy_kv "run-mode" "${CLIPROXY_RUN_MODE:-direct}" "$w"
  _llmproxy_kv "base_url" "${CLIPROXY_URL:-}" "$w"
  _llmproxy_kv "key" "$(_llmproxy_mask "${CLIPROXY_KEY:-}")" "$w"
  _llmproxy_kv "model" "$(_cliproxy_current_model)" "$w"
  _llmproxy_kv "ANTHROPIC_BASE_URL" "${ANTHROPIC_BASE_URL-}" "$w"
  _llmproxy_kv "ANTHROPIC_AUTH_TOKEN" "$(_llmproxy_mask "${ANTHROPIC_AUTH_TOKEN-}")" "$w"
  _llmproxy_kv "ANTHROPIC_MODEL" "${ANTHROPIC_MODEL-}" "$w"
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
  home="${CLIPROXY_HOME}"
  if [[ -z "$home" ]]; then
    _cliproxy_log "CLIPROXY_HOME not set; run from repo or set CLIPROXY_HOME"
    return 1
  fi
  env="${CLIPROXY_ENV:-$home/.llmproxy.env}"
  example="$home/.llmproxy.env.example"
  llmproxy_doctor
  local ans
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
  read -r -s "key?API key (CLIPROXY_KEY_LOCAL) [leave empty to keep]: "
  echo ""
  read -r "run_mode?Run mode (direct/systemd) [${CLIPROXY_RUN_MODE:-direct}]: "
  run_mode="${run_mode:-${CLIPROXY_RUN_MODE:-direct}}"
  read -r "proxy_mode?Proxy mode (proxy/direct) [${LLMPROXY_MODE:-proxy}]: "
  proxy_mode="${proxy_mode:-${LLMPROXY_MODE:-proxy}}"
  read -r "preset?Preset (claude/codex/gemini/antigravity) [${CLIPROXY_PRESET:-claude}]: "
  preset="${preset:-${CLIPROXY_PRESET:-claude}}"

  python3 - "$env" "$base_url" "$key" "$run_mode" "$proxy_mode" "$preset" <<'PY'
import sys, re, shlex
path, base_url, key, run_mode, proxy_mode, preset = sys.argv[1:7]

def clean(v: str) -> str:
    return v.replace("\n", "").replace("\r", "")

base_url = clean(base_url)
key = clean(key)
run_mode = clean(run_mode)
proxy_mode = clean(proxy_mode)
preset = clean(preset)

raw = open(path, "r", encoding="utf-8").read()
# Repair common corruption where literal "\n" ends up inside export lines.
if "\\nexport " in raw or "\\rexport " in raw:
    raw = raw.replace("\\r\\n", "\n").replace("\\n", "\n").replace("\\r", "\n")
data = raw.splitlines(keepends=True)
def set_kv(lines, k, v):
    out = []
    found = False
    for l in lines:
        if l.startswith(f'export {k}='):
            out.append(f'export {k}={shlex.quote(v)}\n')
            found = True
        else:
            out.append(l)
    if not found:
        if out and not out[-1].endswith("\n"):
            out[-1] += "\n"
        out.append(f'export {k}={shlex.quote(v)}\n')
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

  local out checksum_url asset_name
  out="$(python3 - "$json" "$os" "$arch" <<'PY'
import json, sys, re
data = json.loads(sys.argv[1])
os, arch = sys.argv[2], sys.argv[3]
tag = data.get("tag_name","")
name = f"{os}_{arch}.tar.gz"
url = ""
asset_name = ""
checksum_url = ""
checksum_candidates = []
for a in data.get("assets", []):
    n = a.get("name","")
    if n.endswith(name):
        url = a.get("browser_download_url","")
        asset_name = n
    if re.search(r"(sha256|checksums?)", n, re.I):
        checksum_candidates.append((n, a.get("browser_download_url","")))
if checksum_candidates:
    checksum_candidates.sort(key=lambda x: (0 if re.search("sha256", x[0], re.I) else 1, x[0]))
    checksum_url = checksum_candidates[0][1]
print(url)
print(tag)
print(checksum_url)
print(asset_name)
PY
)" || return 1
  url="$(printf "%s" "$out" | sed -n '1p')"
  tag="$(printf "%s" "$out" | sed -n '2p')"
  checksum_url="$(printf "%s" "$out" | sed -n '3p')"
  asset_name="$(printf "%s" "$out" | sed -n '4p')"

  if [[ -z "$url" ]]; then
    _cliproxy_log "no release asset found for ${os}_${arch}"
    return 1
  fi

  tmp="$(mktemp -d)" || return 1
  asset_name="${asset_name:-$(basename "$url")}"
  archive="$tmp/$asset_name"
  curl -L "$url" -o "$archive" || { _cliproxy_log "download failed"; return 1; }
  if [[ -n "$checksum_url" ]]; then
    local checksum_file expected actual
    checksum_file="$tmp/cliproxyapi.checksums"
    curl -L "$checksum_url" -o "$checksum_file" || { _cliproxy_log "checksum download failed"; return 1; }
    expected="$(python3 - "$checksum_file" "$asset_name" <<'PY'
import re, sys
path, name = sys.argv[1], sys.argv[2]
content = open(path, "r", encoding="utf-8", errors="ignore").read()
for line in content.splitlines():
    if name in line:
        parts = line.strip().split()
        if parts:
            print(parts[0])
            raise SystemExit(0)
tokens = content.strip().split()
if len(tokens) == 1 and re.fullmatch(r"[0-9a-fA-F]{64}", tokens[0]):
    print(tokens[0])
PY
)"
    if [[ -z "$expected" ]]; then
      _cliproxy_log "checksum entry not found for ${asset_name}; aborting"
      return 1
    fi
    actual="$(python3 - "$archive" <<'PY'
import hashlib, sys
h = hashlib.sha256()
with open(sys.argv[1], "rb") as f:
    for chunk in iter(lambda: f.read(8192), b""):
        h.update(chunk)
print(h.hexdigest())
PY
)"
    if [[ "$expected" != "$actual" ]]; then
      _cliproxy_log "checksum mismatch for ${asset_name}"
      return 1
    fi
  else
    _cliproxy_log "checksum asset not found; proceeding without verification"
  fi
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
  emulate -L zsh
  setopt local_options
  local _ui_silenced=0
  if typeset -f _cliproxy_ui_silence_xtrace_begin >/dev/null 2>&1; then
    _cliproxy_ui_silence_xtrace_begin
    _ui_silenced=1
  fi
  {
  unsetopt xtrace
  set +x 2>/dev/null || true
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
    unsetopt xtrace
    set +x 2>/dev/null || true
    local full_header="$header"
    if typeset -f _cliproxy_ui_header >/dev/null 2>&1; then
      full_header="$(_cliproxy_ui_header)"$'\n'"$header"
    fi
    if [[ "$picker" == "gum" ]] && command -v gum >/dev/null 2>&1; then
      local term=""
      if gum choose --help 2>&1 | grep -q -- '--filter'; then
        picked="$(printf "%s\n" "$list" | gum choose --header "$full_header" --filter)" || return 1
      else
        term="$(gum input --prompt "Filter (optional): " --placeholder "type to narrow")" || return 1
        if [[ -n "$term" ]]; then
          list="$(printf "%s\n" "$list" | grep -Ei -- "$term" || true)"
          if ! printf "%s\n" "$list" | grep -Fxq -- "$default_label"; then
            list="$(printf "%s\n%s\n" "$default_label" "$list")"
          fi
        fi
        [[ -n "$list" ]] || list="$default_label"
        picked="$(printf "%s\n" "$list" | gum choose --header "$full_header")" || return 1
      fi
    elif command -v fzf >/dev/null 2>&1; then
      if typeset -f _cliproxy_fzf_menu >/dev/null 2>&1; then
        picked="$(printf "%s\n" "$list" | _cliproxy_fzf_menu "Model> " "$full_header" "50%")" || return 1
      else
        picked="$(printf "%s\n" "$list" | fzf --prompt="Model> " --height=50% --border --no-multi --info=hidden --header-first \
          --header="$full_header" \
          --color=fg:252,bg:235,hl:208,fg+:255,bg+:236,hl+:208,info:244,prompt:208,pointer:208,marker:208,spinner:208,header:244,border:238)" || return 1
      fi
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
  } always {
    (( _ui_silenced )) && _cliproxy_ui_silence_xtrace_end
  }
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
  setopt local_options
  unsetopt xtrace verbose
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

  local w=10
  _llmproxy_kv "profile" "${CLIPROXY_PROFILE:-}" "$w"
  _llmproxy_kv "base_url" "${CLIPROXY_URL:-}" "$w"
  _llmproxy_kv "default" "$(_cliproxy_current_model)" "$w"
  _llmproxy_kv "opus" "$opus" "$w"
  _llmproxy_kv "sonnet" "$sonnet" "$w"
  _llmproxy_kv "haiku" "$haiku" "$w"
  _llmproxy_warn_mixed_providers "$opus" "$sonnet" "$haiku"
}

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
