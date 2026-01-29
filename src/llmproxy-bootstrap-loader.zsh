#!/usr/bin/env zsh
# LLMProxy bootstrap loader (new layout)

unsetopt xtrace
set +x 2>/dev/null || true

_llmproxy_bootstrap_dir="$(cd -- "$(dirname -- "${(%):-%N}")" && pwd)"
_llmproxy_root_dir="$(cd -- "$_llmproxy_bootstrap_dir/.." && pwd)"

if [[ -z "${CLIPROXY_HOME:-}" || ! -d "${CLIPROXY_HOME}/src" ]]; then
  export CLIPROXY_HOME="$_llmproxy_root_dir"
fi
export LLMPROXY_HOME_DEFAULT="${CLIPROXY_HOME:-}"

_llmproxy_legacy_notes=""
_llmproxy_legacy_env_path="${CLIPROXY_HOME}/.llmproxy.env"
_llmproxy_config_env_path="${CLIPROXY_HOME}/config/llmproxy.env"

if [[ -n "${CLIPROXY_ENV:-}" && -f "${CLIPROXY_ENV}" ]]; then
  _llmproxy_selected_env="$CLIPROXY_ENV"
else
  if [[ -f "$_llmproxy_config_env_path" ]]; then
    _llmproxy_selected_env="$_llmproxy_config_env_path"
  elif [[ -f "$_llmproxy_legacy_env_path" ]]; then
    _llmproxy_selected_env="$_llmproxy_legacy_env_path"
    _llmproxy_legacy_notes+=$'\n- legacy env file used: .llmproxy.env'
  else
    _llmproxy_selected_env="$_llmproxy_config_env_path"
  fi
fi

if [[ "$_llmproxy_selected_env" == "$_llmproxy_legacy_env_path" ]]; then
  _llmproxy_legacy_notes+=$'\n- legacy env path selected via CLIPROXY_ENV'
fi

export CLIPROXY_ENV="$_llmproxy_selected_env"

if [[ -n "${LLMPROXY_LEGACY_BOOTSTRAP:-}" ]]; then
  _llmproxy_legacy_notes+=$'\n- legacy bootstrap used: '"${LLMPROXY_LEGACY_BOOTSTRAP}"
fi

[[ -f "$CLIPROXY_ENV" ]] && source "$CLIPROXY_ENV"

_llmproxy_modules=(
  "$CLIPROXY_HOME/src/llmproxy-shared-logging.zsh"
  "$CLIPROXY_HOME/src/llmproxy-shared-kv-display.zsh"
  "$CLIPROXY_HOME/src/llmproxy-shared-system-utils.zsh"
  "$CLIPROXY_HOME/src/llmproxy-shared-env-snapshot.zsh"
  "$CLIPROXY_HOME/src/llmproxy-shared-provider-warnings.zsh"
  "$CLIPROXY_HOME/src/llmproxy-shared-model-helpers.zsh"
  "$CLIPROXY_HOME/src/llmproxy-shared-model-listing.zsh"
  "$CLIPROXY_HOME/src/llmproxy-shared-path-helpers.zsh"
  "$CLIPROXY_HOME/src/llmproxy-shared-server-locator.zsh"
  "$CLIPROXY_HOME/src/llmproxy-setup-prompts-and-cliproxyapi-config-generator.zsh"
  "$CLIPROXY_HOME/src/llmproxy-env-apply-restore.zsh"
  "$CLIPROXY_HOME/src/platform/llmproxy-systemd.zsh"
  "$CLIPROXY_HOME/src/platform/llmproxy-launchd.zsh"
  "$CLIPROXY_HOME/src/llmproxy-install-and-setup.zsh"
  "$CLIPROXY_HOME/src/llmproxy-diagnostics-and-env.zsh"
  "$CLIPROXY_HOME/src/llmproxy-model-actions.zsh"
  "$CLIPROXY_HOME/src/llmproxy-model-picker.zsh"
  "$CLIPROXY_HOME/src/llmproxy-run-mode.zsh"
  "$CLIPROXY_HOME/src/llmproxy-server-process-control.zsh"
  "$CLIPROXY_HOME/src/llmproxy-upgrade-and-backup.zsh"
  "$CLIPROXY_HOME/src/llmproxy-ui-state-helpers.zsh"
  "$CLIPROXY_HOME/src/llmproxy-ui-menu-actions.zsh"
  "$CLIPROXY_HOME/src/llmproxy-ui-config.zsh"
  "$CLIPROXY_HOME/src/llmproxy-ui-menu-text.zsh"
  "$CLIPROXY_HOME/src/llmproxy-ui-menu-fzf.zsh"
  "$CLIPROXY_HOME/src/llmproxy-command-router.zsh"
)

for f in "${_llmproxy_modules[@]}"; do
  [[ -f "$f" ]] && source "$f"
done

if [[ -n "$_llmproxy_legacy_notes" && -z "${LLMPROXY_LEGACY_WARNED:-}" ]]; then
  export LLMPROXY_LEGACY_WARNED=1
  if typeset -f _cliproxy_log >/dev/null 2>&1; then
    _cliproxy_log "legacy paths detected (update to new layout):"
    printf "%s\n" "${_llmproxy_legacy_notes#\n}"
  fi
fi

unsetopt xtrace
set +x 2>/dev/null || true

if typeset -f _cliproxy_apply >/dev/null 2>&1; then
  _cliproxy_apply
fi
