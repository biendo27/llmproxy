# Upgrade/backup CLIProxyAPI binary

_llmproxy_brew_install_cliproxyapi() {
  if ! _llmproxy_has_cmd brew; then
    return 1
  fi
  if brew list --formula cliproxyapi >/dev/null 2>&1; then
    brew upgrade cliproxyapi || brew reinstall cliproxyapi
    return $?
  fi
  brew install cliproxyapi
}

_llmproxy_linux_install_cliproxyapi() {
  local url
  if ! _llmproxy_has_cmd curl; then
    _cliproxy_log "curl not found; cannot run installer script"
    return 1
  fi
  url="${CLIPROXY_INSTALLER_URL:-https://raw.githubusercontent.com/brokechubb/cliproxyapi-installer/refs/heads/master/cliproxyapi-installer}"
  _cliproxy_log "running CLIProxyAPI installer script"
  curl -fsSL "$url" | bash
}

cliproxy_install() {
  local os
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  if [[ "$os" == "darwin" ]]; then
    if _llmproxy_brew_install_cliproxyapi; then
      return 0
    fi
    _cliproxy_log "brew not available; falling back to GitHub release"
  elif [[ "$os" == "linux" ]]; then
    if _llmproxy_linux_install_cliproxyapi; then
      return 0
    fi
    _cliproxy_log "installer script failed; falling back to GitHub release"
  fi
  cliproxy_upgrade
}

cliproxy_upgrade() {
  local os arch json url tag tmp archive newbin target running
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(_llmproxy_arch)"
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
tag = data.get("tag_name", "")
name = f"{os}_{arch}.tar.gz"
url = ""
asset_name = ""
checksum_url = ""
checksum_candidates = []
for a in data.get("assets", []):
    n = a.get("name", "")
    if n.endswith(name):
        url = a.get("browser_download_url", "")
        asset_name = n
    if re.search(r"(sha256|checksums?)", n, re.I):
        checksum_candidates.append((n, a.get("browser_download_url", "")))
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

  if ! mkdir -p "$(dirname "$target")"; then
    _cliproxy_log "failed to create target dir: $(dirname "$target")"
    return 1
  fi

  running=0
  local run_mode="${CLIPROXY_RUN_MODE:-direct}"
  [[ "$run_mode" == "systemd" ]] && run_mode="background"
  if [[ "$run_mode" == "background" ]]; then
    if _cliproxy_is_macos; then
      launchctl list 2>/dev/null | grep -q "${CLIPROXY_LAUNCHD_LABEL:-com.cliproxyapi}" && running=1
    else
      systemctl --user is-active --quiet "${CLIPROXY_SYSTEMD_SERVICE:-cliproxyapi}.service" && running=1
    fi
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
