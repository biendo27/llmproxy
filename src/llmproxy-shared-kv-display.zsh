# Key/value display helper

_llmproxy_kv() {
  local key="$1"
  local val="$2"
  local width="${3:-16}"
  printf "  %-*s : %s\n" "$width" "$key" "$val"
}
