# Codebase Summary

## Repository Purpose
LLMProxy provides a zsh-based wrapper around CLIProxyAPI to manage model routing and environment variables for Claude Code (and other tools). It offers an interactive menu (fzf or text) and one-line commands to select presets, models, and proxy vs official Claude mode.

## Top-Level Structure
- `bin/llmproxy`: Bash entrypoint that resolves paths and invokes zsh with the wrapper loaded.
- `llmproxy`: Root wrapper that forwards to `bin/llmproxy`.
- `src/llmproxy-bootstrap-loader.zsh`: Bootstrap loader; sources env and split modules.
- `src/`: Core modules (commands, UI, server control, helpers).
- `src/platform/`: OS-specific launchd/systemd helpers.
- `config/llmproxy.env.example`: Environment template for profiles, model defaults, and run mode.
- `config/config.example.yaml`: CLIProxyAPI server configuration template.
- `README.md`: User-focused usage and setup instructions.

## Entry Points
- `./llmproxy setup`: Setup wizard (env file creation, deps check, auto-source).
- `bin/llmproxy`: Interactive menu and command router for daily usage.
- `source src/llmproxy-bootstrap-loader.zsh`: Manual activation of the environment and functions.

## Core Flows
### 1) Bootstrap
- `bin/llmproxy` resolves its path, ensures zsh is available, then runs `zsh -lc`.
- `src/llmproxy-bootstrap-loader.zsh` sets the home path, loads `config/llmproxy.env`, and sources core/UI modules.

### 2) Apply Proxy Environment
- `src/llmproxy-env-apply-restore.zsh` snapshots existing Anthropic env and applies proxy variables when mode is `proxy`.
- If `LLMPROXY_MODE=official`, it restores original env values.

### 3) Model Selection
- Presets (`claude`, `codex`, `gemini`, `antigravity`) map to model tier variables in `config/llmproxy.env`.
- Direct model override in `config/llmproxy.env` takes precedence, with optional thinking level suffix.

### 4) UI Selection
- If `fzf` is installed, menu actions use fzf for selection.
- If not, the UI falls back to text prompts.

## Configuration Files
- `config/llmproxy.env.example`: Primary template for user configuration. Copied to `config/llmproxy.env`.
- `config/config.example.yaml`: CLIProxyAPI server configuration template.

## External Dependencies
- Required: `zsh`, `curl`, `python3`
- Optional: `fzf` for enhanced UI

## Security Notes
- `config/llmproxy.env` and `config.yaml` contain secrets and are gitignored.
- Proxy auth uses values defined in `config/llmproxy.env`.

## Documentation Coverage
- This summary reflects the current repo layout (no `docs/` previously existed).
- See `docs/system-architecture.md` for component interactions and data flow.
