# System Architecture

## Overview
LLMProxy is a shell-based wrapper that configures environment variables for Claude Code to route requests through a CLIProxyAPI server. It provides a CLI menu and one-line commands to control proxy mode, presets, and model selection.

## Components
- **Entry Script (`bin/llmproxy`)**: Bash wrapper that resolves its path and runs zsh with the LLMProxy environment loaded.
- **Root Wrapper (`llmproxy`)**: Forwards to `bin/llmproxy` for compatibility.
- **Bootstrap (`src/llmproxy-bootstrap-loader.zsh`)**: Sets the home path, loads `config/llmproxy.env`, and sources split modules.
- **Core Modules (`src/*.zsh`)**: Command routing, setup/install flows, diagnostics, model actions.
- **UI Modules (`src/llmproxy-ui-*.zsh`)**: fzf/text menu rendering and UI state helpers.
- **Platform Modules (`src/platform/*`)**: launchd (macOS) and systemd (Linux) integrations.
- **Configuration (`config/llmproxy.env`)**: User-edited environment values and model defaults.
- **Generated CLIProxyAPI config (`config/cliproxyapi-local-config.yaml`)**: Optional local server config created by setup (gitignored).
- **CLIProxyAPI Server (external)**: Provides `/v1/models` and proxy behavior; configured via the safe template (`config/cliproxyapi-safe-defaults-config-template.yaml`) or the generated local config when self-hosted.

## Data Flow
1. **Invocation**: User runs `llmproxy` or a subcommand.
2. **Bootstrap**: `bin/llmproxy` loads `src/llmproxy-bootstrap-loader.zsh`, which sources env and modules.
3. **Command Routing**: Core module parses the command and invokes actions (use preset, toggle mode, etc.).
4. **Environment Apply**: Apply module sets or restores Anthropic env vars based on mode and selected preset/model.
5. **Setup Config Generation (Optional)**: Setup can generate `config/cliproxyapi-local-config.yaml` and update local profile defaults in `config/llmproxy.env`.
6. **Model Sync (Optional)**: Model selection may query `/v1/models` when proxy values are configured.

## Mode Switching
- **Proxy mode**: Sets Anthropic environment variables to CLIProxyAPI values.
- **Official mode**: Restores original Anthropic environment variables captured at startup.

## Platform Integration
- **macOS**: Background mode managed via launchd (plist in `~/Library/LaunchAgents/`).
- **Linux**: Background mode managed via systemd services.

## Security Considerations
- `config/llmproxy.env` and generated `config/cliproxyapi-local-config.yaml` contain secrets and are gitignored.
- Configuration values are sourced from `config/llmproxy.env` which is created from `config/llmproxy.env.example`.
- Environment variables are applied only when explicitly in proxy mode.

## Observability
- User-facing output is provided via `_cliproxy_log` and status views in the UI.
