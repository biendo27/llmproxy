# Logging helpers

_cliproxy_log() {
  if [[ "${CLIPROXY_LOG_SEP:-1}" != "0" ]]; then
    printf "\n[llmproxy] ------------------------------\n"
  fi
  printf "[llmproxy] %s\n" "$*"
}
