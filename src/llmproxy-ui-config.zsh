# UI configuration menu (fzf only)

llmproxy_ui_config() {
  emulate -L zsh
  _cliproxy_ui_no_xtrace
  _cliproxy_ui_silence_xtrace_begin
  if ! _cliproxy_has_fzf; then
    _cliproxy_log "fzf not found; UI config requires fzf."
    return 1
  fi

  while true; do
    local -a item_lines=()
    local mode="${LLMPROXY_UI_MODE:-expanded}"
    local theme="${LLMPROXY_UI_THEME:-claude}"
    local preview="${LLMPROXY_UI_PREVIEW:-0}"
    local grouped="${LLMPROXY_UI_GROUPED:-1}"
    local keys="${LLMPROXY_UI_QUICK_KEYS:-1}"

    local choice items item_w=24
    item_lines+=("$(_llmproxy_menu_item "Mode: ${mode}" "compact | expanded | preview" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Theme: ${theme}" "claude | codex | mono" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Preview panel: ${preview}" "0=off | 1=on" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Grouped sections: ${grouped}" "0=off | 1=on" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Quick keys: ${keys}" "Ctrl+P/O/S/E" "$item_w")")
    item_lines+=("$(_llmproxy_menu_item "Back" "return" "$item_w")")
    items="${(F)item_lines}"

    choice="$(printf "%s" "$items" | \
      _cliproxy_fzf_menu "UI> " "$(_cliproxy_ui_header)" "40%" --delimiter=$'\t' --with-nth=1,2 --nth=1,2)" || return

    choice="${choice%%$'\t'*}"
    choice="${choice%"${choice##*[![:space:]]}"}"
    case "$choice" in
      "Mode:"*)
        mode="$(printf "%s\n" compact expanded preview | _cliproxy_fzf_menu "Mode> " "$(_cliproxy_ui_header)" "40%")" || continue
        export LLMPROXY_UI_MODE="$mode"
        ;;
      "Theme:"*)
        theme="$(printf "%s\n" claude codex mono | _cliproxy_fzf_menu "Theme> " "$(_cliproxy_ui_header)" "40%")" || continue
        export LLMPROXY_UI_THEME="$theme"
        ;;
      "Preview panel:"*)
        preview="$(printf "%s\n" 0 1 | _cliproxy_fzf_menu "Preview> " "$(_cliproxy_ui_header)" "40%")" || continue
        export LLMPROXY_UI_PREVIEW="$preview"
        ;;
      "Grouped sections:"*)
        grouped="$(printf "%s\n" 1 0 | _cliproxy_fzf_menu "Grouped> " "$(_cliproxy_ui_header)" "40%")" || continue
        export LLMPROXY_UI_GROUPED="$grouped"
        ;;
      "Quick keys:"*)
        keys="$(printf "%s\n" 1 0 | _cliproxy_fzf_menu "Quick keys> " "$(_cliproxy_ui_header)" "40%")" || continue
        export LLMPROXY_UI_QUICK_KEYS="$keys"
        ;;
      "Back") break ;;
    esac
  done
  _cliproxy_ui_silence_xtrace_end
}
