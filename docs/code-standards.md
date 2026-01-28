# Code Standards

## Purpose
This document describes the structural and style conventions used in this repository based on the current codebase. It is intended to help contributors keep changes consistent with existing patterns.

## File Layout
- `bin/llmproxy`: Bash entrypoint that resolves the script path and executes the zsh-based CLI.
- `llmproxy`: Root wrapper that forwards to `bin/llmproxy`.
- `src/llmproxy-bootstrap-loader.zsh`: Bootstrap loader; sets the repo home path, loads env, and sources modules.
- `src/*.zsh`: Core modules (commands, UI, helpers).
- `src/platform/*.zsh`: OS-specific modules (launchd/systemd).
- `config/llmproxy.env.example`: Env template used to create `config/llmproxy.env`.
- `config/config.example.yaml`: CLIProxyAPI server configuration template.

## Naming Conventions
- Shell functions use snake_case with `_cliproxy_` or `_llmproxy_` prefixes (e.g., `_cliproxy_log`).
- Environment variables are defined in `config/llmproxy.env.example` and exported via `config/llmproxy.env`.
- Files use kebab-case descriptive names under `src/` and `config/`.

## Shell Script Guidelines
- Prefer zsh for core logic (`src/*.zsh`), with `bin/llmproxy` as a bash entrypoint.
- Use `set -euo pipefail` in bash entrypoints for safety.
- Guard commands with availability checks (`command -v`).
- Keep interactive flows tolerant of missing optional deps (fzf fallback to text prompts).

## Environment Handling
- Always snapshot and restore the original Anthropic env before applying proxy settings.
- Keep secrets out of git: `config/llmproxy.env` and `config.yaml` are ignored.
- Reference `config/llmproxy.env.example` when describing available environment values.

## Configuration Sources
- `config/llmproxy.env` is the canonical runtime configuration for profiles, models, and modes.
- `config.yaml` is only required when running the CLIProxyAPI server locally.

## Error Handling & Logging
- Use `_cliproxy_log` for user-facing messages.
- Return non-zero exit status for unmet prerequisites or invalid configuration.

## Documentation Update Rules
- Update `README.md` for any user-facing command changes.
- Update docs in `./docs` when core behavior or configuration changes.
