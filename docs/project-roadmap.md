# Project Roadmap

## Current Status
- Phase: Maintenance
- Focus: Stability, compatibility with CLIProxyAPI, and documentation accuracy.

## Milestones
| Milestone | Status | Notes |
| --- | --- | --- |
| Core CLI wrapper and bootstrap | Complete | `llmproxy` entrypoint and `.llmproxy.zsh` loader. |
| Model presets and env apply | Complete | Preset mapping and `ANTHROPIC_*` env apply/restore. |
| Interactive menu (fzf/text) | Complete | UI module supports fzf or text fallback. |
| Background run mode support | Complete | Launchd (macOS) and systemd (Linux). |
| Initial documentation set | In progress | Creating `docs/` baseline and updating README. |

## Near-Term Tasks
- Keep README and docs in sync with CLI behavior.
- Validate new model defaults when CLIProxyAPI changes.

## Long-Term Considerations
- None declared in repository at this time.
