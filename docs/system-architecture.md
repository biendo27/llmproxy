# System Architecture

## Overview
LLMProxy is a shell-based wrapper that configures environment variables for Claude Code to route requests through a CLIProxyAPI server. It provides a CLI menu and one-line commands to control proxy mode, presets, and model selection.

## Components
- **Entry Script (`llmproxy`)**: Bash wrapper that resolves its path and runs zsh with the LLMProxy environment loaded.
- **Bootstrap (`.llmproxy.zsh`)**: Sets the home path, loads `.llmproxy.env`, and sources core/UI modules.
- **Core Module (`.llmproxy.core.zsh`)**: Command routing, setup/install flows, and dependency checks.
- **UI Module (`.llmproxy.ui.zsh`)**: fzf-based menus with text fallback and status views.
- **Library Module (`.llmproxy.lib.zsh`)**: Logging, env snapshot/restore, model helpers.
- **Apply Module (`.llmproxy.apply.zsh`)**: Applies or restores Anthropic env variables based on mode/preset.
- **Configuration (`.llmproxy.env`)**: User-edited environment values and model defaults.
- **CLIProxyAPI Server (external)**: Provides `/v1/models` and proxy behavior; configured via `config.yaml` if self-hosted.

## Data Flow
1. **Invocation**: User runs `llmproxy` or a subcommand.
2. **Bootstrap**: `llmproxy` loads `.llmproxy.zsh`, which sources env and modules.
3. **Command Routing**: Core module parses the command and invokes actions (use preset, toggle mode, etc.).
4. **Environment Apply**: Apply module sets or restores Anthropic env vars based on mode and selected preset/model.
5. **Model Sync (Optional)**: Model selection may query `/v1/models` when proxy values are configured.

## Mode Switching
- **Proxy mode**: Sets Anthropic environment variables to CLIProxyAPI values.
- **Official mode**: Restores original Anthropic environment variables captured at startup.

## Platform Integration
- **macOS**: Background mode managed via launchd (plist in `~/Library/LaunchAgents/`).
- **Linux**: Background mode managed via systemd services.

## Security Considerations
- `.llmproxy.env` and `config.yaml` contain secrets and are gitignored.
- Configuration values are sourced from `.llmproxy.env` which is created from `.llmproxy.env.example`.
- Environment variables are applied only when explicitly in proxy mode.

## Observability
- User-facing output is provided via `_cliproxy_log` and status views in the UI.
