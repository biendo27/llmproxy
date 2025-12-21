# LLMProxy config (CLIProxyAPI wrapper)

This folder contains all LLMProxy shell config files so you can sync them to git
and reuse on other machines.

## Files

- `.llmproxy.env` - profiles, API keys, model defaults
- `.llmproxy.env.example` - safe template (no real keys)
- `.llmproxy.zsh` - bootstrap loader (sets CLIPROXY_HOME and sources modules)
- `.llmproxy.core.zsh` - core logic (apply env, model mapping, /v1/models picker)
- `.llmproxy.ui.zsh` - UI (fzf/text menu)

## Quick setup (zsh)

1) Copy or clone this folder to the target machine
2) Copy the env template and fill in real keys:

```zsh
cp /path/to/llmproxy-config/.llmproxy.env.example /path/to/llmproxy-config/.llmproxy.env
```

3) Run setup wizard (recommended):

```zsh
./llmproxy setup
```

or source the bootstrap file manually:

```zsh
source /path/to/llmproxy-config/.llmproxy.zsh
```

Optional: add the line above into `~/.zshrc` so it loads automatically.
Example (generic, path-safe):

```zsh
if command -v llmproxy >/dev/null 2>&1; then eval "$(llmproxy init)"; fi
```

## Prerequisites

Required:
- `zsh`
- `curl`
- `python3`

Optional (for better UI):
- `fzf` (interactive picker)

Install examples:

Linux (Ubuntu/Debian):
```zsh
sudo apt update && sudo apt install -y curl python3 fzf
```

macOS (Homebrew):
```zsh
brew install curl python fzf
```

## Usage

```zsh
llmproxy                 # interactive menu
llmproxy use codex        # switch preset (claude/codex/gemini/antigravity)
llmproxy use <model>      # use a specific model id
llmproxy pick-model       # pick from /v1/models
llmproxy status           # show current status
llmproxy start            # start server (direct or systemd)
llmproxy stop             # stop server
llmproxy restart          # restart server
llmproxy server-status    # show server status
llmproxy upgrade          # download latest CLIProxyAPI binary
llmproxy backup           # create a timestamped backup of the binary
```

Legacy alias:

```zsh
cliproxy ...   # still works for backward compatibility
```

## Switch between proxy and official Claude

You can quickly disable the proxy env (use Claude official subscription) and
enable it back when needed:

```zsh
llmproxy off      # use official Claude (no proxy env)
llmproxy on       # re-enable proxy env
llmproxy toggle   # switch between the two
```

Persist default mode in `.llmproxy.env`:

```zsh
export LLMPROXY_MODE="proxy"  # or "direct"
```

## One-time setup & health check

```zsh
llmproxy setup     # wizard: env + auto-source + deps
llmproxy install   # add auto-source to shell rc
llmproxy fix       # auto-install missing deps
llmproxy doctor    # check deps, server reachability, OS, mode
```

Tip: after git clone, you can run `./llmproxy setup` directly from this folder
even before adding anything to your shell rc.

## Server setup (config.yaml)

These scripts talk to CLIProxyAPI, so your `config.yaml` must match the
connection info in `.llmproxy.env`.

Checklist:

- **Start from template**: copy `config.example.yaml` (this folder) to
  `config.yaml` and replace placeholders.
- **Base URL**: the `CLIPROXY_URL` in `.llmproxy.env` (default
  `http://127.0.0.1:8317`) must match the server host/port in `config.yaml`.
- **Auth files**: make sure your OAuth JSON files live in the directory your
  server expects (e.g. `~/.cli-proxy-api`). The server reads them on startup.
- **Management UI**: if you use the web UI, set a management key in
  `config.yaml`. The file stores the **hashed** value; the UI login expects the
  **original plaintext** you set. If you changed it and don’t remember, set a
  new plaintext value in `config.yaml` and restart the server.

After editing `config.yaml`, restart CLIProxyAPI.

## macOS support

The tools work on macOS with a few notes:

- `llmproxy upgrade` supports **darwin** (arm64/amd64) and will download the
  correct binary for your CPU.
- `systemd` is **not available** on macOS, so use **direct** mode:

```zsh
llmproxy run-mode direct
```

Supported on macOS:
- `llmproxy on/off/toggle`
- `llmproxy use / pick-model / status`
- `llmproxy upgrade`
- `llmproxy` UI (fzf)

Not applicable on macOS:
- `llmproxy systemd-install`
- `llmproxy systemd-enable`
- `llmproxy run-mode systemd`

## Run mode (direct vs systemd)

Default mode is **direct** (runs `./cli-proxy-api` with `--config`).

Switch in the current shell:

```zsh
llmproxy run-mode direct
llmproxy run-mode systemd
llmproxy run-mode systemd --persist  # save into .llmproxy.env
```

To persist, edit `.llmproxy.env` and set:

```zsh
export CLIPROXY_RUN_MODE="direct" # or "systemd"
```

Systemd setup (user service):

```zsh
llmproxy systemd-install   # write unit file
llmproxy systemd-enable    # enable + start
```

Note: systemd is Linux-only. On macOS, use **direct** mode.

Upgrade to latest release:

```zsh
llmproxy upgrade
```

## Notes / security

- `.llmproxy.env` contains API keys. Use a private repo, or replace keys before
  pushing.
- If you do not want to sync secrets, keep `.llmproxy.env` out of git and
  create a machine-local file (e.g. `.llmproxy.env.local`) then point
  `CLIPROXY_ENV` to it before sourcing `.llmproxy.zsh`.
- You can override paths:
  - `CLIPROXY_HOME` points to this folder
  - `CLIPROXY_ENV` points to the env file
  
**Public repo warning:** do **not** publish real keys in a public GitHub repo.
Treat any leaked keys as compromised and rotate/revoke them immediately.
This repo includes a `.gitignore` to avoid committing `config.yaml` and
`.llmproxy.env` by default.

## Model defaults

Defaults are defined in `.llmproxy.env`:

- `CLIPROXY_CLAUDE_*`, `CLIPROXY_CODEX_*`, `CLIPROXY_GEMINI_*`
- Codex thinking levels: `CLIPROXY_CODEX_THINKING_*`
- Preset: `CLIPROXY_PRESET` (claude by default)

After editing `.llmproxy.env`, run:

```zsh
source /path/to/llmproxy-config/.llmproxy.zsh
```
