# Run mode helpers

cliproxy_run_mode() {
  local mode="${1:-}"
  local persist="${2:-}"
  if [[ -z "$mode" ]]; then
    _cliproxy_log "run mode: ${CLIPROXY_RUN_MODE:-direct}"
    return 0
  fi
  [[ "$mode" == "systemd" ]] && mode="background"
  case "$mode" in
    direct|background) export CLIPROXY_RUN_MODE="$mode" ;;
    *)
      echo "Usage: cliproxy_run_mode <direct|background> [--persist]"
      return 1
      ;;
  esac
  if [[ "$persist" == "--persist" && -n "${CLIPROXY_ENV:-}" && -f "${CLIPROXY_ENV}" ]]; then
    python3 - "$CLIPROXY_ENV" "$mode" <<'PY'
import sys
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
