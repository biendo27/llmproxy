# Install + setup flows

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

  local portable_src="$src"
  if [[ "$src" == "$HOME"* ]]; then
    portable_src="\$HOME${src#$HOME}"
  fi
  local export_line="export CLIPROXY_HOME=\"${portable_src}\""
  local source_line='[[ -f "$CLIPROXY_HOME/src/llmproxy-bootstrap-loader.zsh" ]] && source "$CLIPROXY_HOME/src/llmproxy-bootstrap-loader.zsh"'

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
  src="$home/src/llmproxy-bootstrap-loader.zsh"
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

llmproxy_setup() {
  local home env example base_url key run_mode
  local config_written=0 config_env_set=0
  local config_path api_key web_ui_enabled
  local cliproxy_bin
  home="${CLIPROXY_HOME}"
  if [[ -z "$home" ]]; then
    _cliproxy_log "CLIPROXY_HOME not set; run from repo or set CLIPROXY_HOME"
    return 1
  fi
  env="${CLIPROXY_ENV:-$home/config/llmproxy.env}"
  example="$home/config/llmproxy.env.example"
  llmproxy_doctor
  local ans
  read -r "ans?Auto-fix missing deps? (y/N): "
  if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
    llmproxy_fix
  fi

  if _llmproxy_prompt_yes_no "Install/upgrade CLIProxyAPI binary?" "y"; then
    cliproxy_upgrade || return 1
  else
    cliproxy_bin="$(_cliproxy_server_bin 2>/dev/null)"
    if [[ -z "$cliproxy_bin" ]]; then
      _cliproxy_log "CLIProxyAPI binary not found; run 'llmproxy upgrade'"
    fi
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

  config_path="$home/config/cliproxyapi-local-config.yaml"
  if [[ -f "$config_path" ]]; then
    if _llmproxy_prompt_yes_no "Use existing CLIProxyAPI config at ${config_path}?" "y"; then
      config_env_set=1
    fi
  elif _llmproxy_has_cmd python3 && _llmproxy_prompt_yes_no "Generate CLIProxyAPI config at ${config_path}?" "y"; then
    if _llmproxy_prompt_yes_no "Enable CLIProxyAPI Web UI (management panel)?" "y"; then
      web_ui_enabled="true"
    else
      web_ui_enabled="false"
    fi
    read -r -s "api_key?API key for CLIProxyAPI (leave empty to keep placeholder): "
    echo ""
    _llmproxy_write_config_yaml "$config_path" "" "8317" "~/.cli-proxy-api" "$api_key" "$web_ui_enabled"
    config_written=1
    config_env_set=1
  fi

  if [[ ! -f "$config_path" ]]; then
    if ! _llmproxy_has_cmd python3; then
      _cliproxy_log "python3 is required to generate CLIProxyAPI config"
    elif [[ "${CLIPROXY_CONFIG:-}" == "$config_path" ]]; then
      _cliproxy_log "CLIProxyAPI config missing at ${config_path}"
    fi
  fi

  local proxy_mode preset rc_path
  read -r "base_url?Base URL [${CLIPROXY_URL_LOCAL:-http://127.0.0.1:8317}]: "
  base_url="${base_url:-${CLIPROXY_URL_LOCAL:-http://127.0.0.1:8317}}"
  read -r -s "key?API key (CLIPROXY_KEY_LOCAL) [leave empty to keep]: "
  echo ""
  if (( config_written )); then
    if [[ -n "$key" ]]; then
      api_key="$key"
      _llmproxy_write_config_yaml "$config_path" "" "8317" "~/.cli-proxy-api" "$api_key" "$web_ui_enabled"
    elif [[ -n "$api_key" ]]; then
      key="$api_key"
    fi
  elif (( config_env_set )) && [[ -n "$key" ]]; then
    _cliproxy_log "note: update api-keys in ${config_path} to match CLIPROXY_KEY_LOCAL"
  fi
  read -r "run_mode?Run mode (direct/background) [${CLIPROXY_RUN_MODE:-direct}]: "
  run_mode="${run_mode:-${CLIPROXY_RUN_MODE:-direct}}"
  read -r "proxy_mode?Proxy mode (proxy/official) [${LLMPROXY_MODE:-proxy}]: "
  proxy_mode="${proxy_mode:-${LLMPROXY_MODE:-proxy}}"
  read -r "preset?Preset (claude/codex/gemini/antigravity) [${CLIPROXY_PRESET:-claude}]: "
  preset="${preset:-${CLIPROXY_PRESET:-claude}}"

  python3 - "$env" "$base_url" "$key" "$run_mode" "$proxy_mode" "$preset" "$config_path" "$config_written" "$config_env_set" <<'PY'
import sys, shlex
path, base_url, key, run_mode, proxy_mode, preset, config_path, config_written, config_env_set = sys.argv[1:10]

def clean(v: str) -> str:
    return v.replace("\n", "").replace("\r", "")

base_url = clean(base_url)
key = clean(key)
run_mode = clean(run_mode)
proxy_mode = clean(proxy_mode)
preset = clean(preset)

raw = open(path, "r", encoding="utf-8").read()
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
if config_written == "1" or config_env_set == "1":
    data = set_kv(data, "CLIPROXY_CONFIG", config_path)
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
