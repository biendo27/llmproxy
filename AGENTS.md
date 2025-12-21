# Repository Guidelines

## Project Structure & Module Organization
- `llmproxy` is the portable bash wrapper that execs zsh and loads the tool.
- `.llmproxy.zsh` is the bootstrap loader; `.llmproxy.core.zsh` holds the main CLI commands.
- `.llmproxy.lib.zsh` contains shared helpers; `.llmproxy.ui.zsh` renders the menu/picker; `.llmproxy.apply.zsh` applies env changes.
- `.llmproxy.env` (ignored) stores local secrets; `.llmproxy.env.example` is the safe template.
- `config.example.yaml` is the server config template (only needed if you run CLIProxyAPI).

## Build, Test, and Development Commands
- `./llmproxy setup`: one-time wizard to create `.llmproxy.env`, install deps, and add shell auto-source.
- `llmproxy`: open the interactive menu (fzf UI if installed, text menu otherwise).
- `llmproxy doctor`: verify prerequisites, PATH, and server reachability.
- `llmproxy sync-models claude`: refresh preset models from `/v1/models`.
- `llmproxy run-mode direct|systemd`: switch how the local server is run (systemd is Linux-only).

## Coding Style & Naming Conventions
- Shell-only repo: bash wrapper plus zsh libraries. Keep scripts POSIX-friendly where feasible.
- Indent with 2 spaces; avoid tabs. Use `local` for function variables.
- Public commands use `llmproxy_*`; internal helpers use `_llmproxy_*` or `_cliproxy_*`.
- Environment variables are uppercase (`CLIPROXY_*`, `LLMPROXY_*`). Secrets never go in git.

## Testing Guidelines
- No automated test suite yet. Use manual checks:
  - `llmproxy doctor` and `llmproxy status`
  - `llmproxy pick-model` and a model switch to confirm env updates
- If adding tests, place them under a new `tests/` folder and document how to run them.

## Commit & Pull Request Guidelines
- Commit messages are short, imperative, and capitalized (e.g., `Refactor model picker`).
- Keep PRs focused and include:
  - Summary of behavior changes
  - Manual test notes (commands run)
  - Any config/env changes or new variables

## Security & Configuration Tips
- Never commit `.llmproxy.env` or `config.yaml`; use `.llmproxy.env.example` and `config.example.yaml` instead.
- If keys leak, rotate them immediately and verify with `llmproxy doctor`.
