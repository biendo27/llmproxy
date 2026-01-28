# Project Overview & PDR

## Overview
LLMProxy is a small shell-based wrapper around CLIProxyAPI that makes it easy to switch models and routing for Claude Code (and other tools) on macOS and Linux. It provides a menu-driven UI (fzf or text) and one-line commands to toggle between proxy and official Claude, select presets, and manage local background run modes for the CLIProxyAPI server.

## Goals
- Simple, low-friction model switching for CLIProxyAPI-backed workflows.
- Safe, explicit environment configuration through a template-driven `.llmproxy.env`.
- Cross-platform support for macOS (launchd) and Linux (systemd) background modes.
- Fast setup via a single `./llmproxy setup` wizard.

## Non-Goals
- Implementing the CLIProxyAPI server itself.
- Managing API keys beyond loading them from `.llmproxy.env`.
- Providing a GUI beyond terminal-based menus.

## Target Users
- Developers using Claude Code who want to route through CLIProxyAPI.
- Teams needing quick model switching across Claude/Codex/Gemini tiers.
- Users who want a minimal shell-based workflow with optional TUI.

## Functional Requirements
- Bootstrap from repo root with `./llmproxy setup` and source `src/llmproxy-bootstrap-loader.zsh`.
- Apply env variables for Claude Code (ANTHROPIC_* and related defaults).
- Support presets (claude/codex/gemini/antigravity) and direct model IDs.
- Provide interactive selection (fzf) and a text fallback when fzf is missing.
- Provide `llmproxy on/off/toggle` to switch proxy vs official mode.
- Provide background install commands for systemd/launchd where supported.

## Non-Functional Requirements
- Must run on macOS and Linux with zsh available.
- Must keep sensitive keys out of git by default (`config/llmproxy.env`, `config.yaml`).
- Use simple, readable shell code and Python for small utilities only.

## Constraints
- Shell environment is zsh; wrapper ensures zsh for command execution.
- CLIProxyAPI must be running for `/v1/models` interactions.
- Configuration is file-based (no external config service).

## Acceptance Criteria
- A new user can run `./llmproxy setup`, source the shell, and open the menu.
- Presets update the applied Anthropic environment variables as expected.
- `llmproxy off` restores original Anthropic environment variables.
- Background mode commands are available per OS.

## Version History
- 2026-01-28: Initial PDR created based on current repository.
