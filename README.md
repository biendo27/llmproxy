# LLMProxy config (CLIProxyAPI wrapper)

This folder contains all LLMProxy shell config files so you can sync them to git
and reuse on other machines.

## Files

- `.cliproxy.env` - profiles, API keys, model defaults
- `.cliproxy.env.example` - safe template (no real keys)
- `.cliproxy.zsh` - bootstrap loader (sets CLIPROXY_HOME and sources modules)
- `.cliproxy.core.zsh` - core logic (apply env, model mapping, /v1/models picker)
- `.cliproxy.ui.zsh` - UI (fzf/text menu)

## Quick setup (zsh)

1) Copy or clone this folder to the target machine
2) Copy the env template and fill in real keys:

```zsh
cp /path/to/cliproxy-config/.cliproxy.env.example /path/to/cliproxy-config/.cliproxy.env
```

3) Source the bootstrap file:

```zsh
source /path/to/cliproxy-config/.cliproxy.zsh
```

Optional: add the line above into `~/.zshrc` so it loads automatically.
Example (this repo path):

```zsh
[ -f "$HOME/cliproxyapi/cliproxy-config/.cliproxy.zsh" ] && source "$HOME/cliproxyapi/cliproxy-config/.cliproxy.zsh"
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

## Server setup (config.yaml)

These scripts talk to CLIProxyAPI, so your `config.yaml` must match the
connection info in `.cliproxy.env`.

Checklist:

- **Start from template**: copy `config.example.yaml` (this folder) to
  `config.yaml` and replace placeholders.
- **Base URL**: the `CLIPROXY_URL` in `.cliproxy.env` (default
  `http://127.0.0.1:8317`) must match the server host/port in `config.yaml`.
- **Auth files**: make sure your OAuth JSON files live in the directory your
  server expects (e.g. `~/.cli-proxy-api`). The server reads them on startup.
- **Management UI**: if you use the web UI, set a management key in
  `config.yaml`. The file stores the **hashed** value; the UI login expects the
  **original plaintext** you set. If you changed it and don’t remember, set a
  new plaintext value in `config.yaml` and restart the server.

After editing `config.yaml`, restart CLIProxyAPI.

## Run mode (direct vs systemd)

Default mode is **direct** (runs `./cli-proxy-api` with `--config`).

Switch in the current shell:

```zsh
llmproxy run-mode direct
llmproxy run-mode systemd
llmproxy run-mode systemd --persist  # save into .cliproxy.env
```

To persist, edit `.cliproxy.env` and set:

```zsh
export CLIPROXY_RUN_MODE="direct" # or "systemd"
```

Systemd setup (user service):

```zsh
llmproxy systemd-install   # write unit file
llmproxy systemd-enable    # enable + start
```

Upgrade to latest release:

```zsh
llmproxy upgrade
```

## Notes / security

- `.cliproxy.env` contains API keys. Use a private repo, or replace keys before
  pushing.
- If you do not want to sync secrets, keep `.cliproxy.env` out of git and
  create a machine-local file (e.g. `.cliproxy.env.local`) then point
  `CLIPROXY_ENV` to it before sourcing `.cliproxy.zsh`.
- You can override paths:
  - `CLIPROXY_HOME` points to this folder
  - `CLIPROXY_ENV` points to the env file
  
**Public repo warning:** do **not** publish real keys in a public GitHub repo.
Treat any leaked keys as compromised and rotate/revoke them immediately.
This repo includes a `.gitignore` to avoid committing `config.yaml` and
`.cliproxy.env` by default.

## Model defaults

Defaults are defined in `.cliproxy.env`:

- `CLIPROXY_CLAUDE_*`, `CLIPROXY_CODEX_*`, `CLIPROXY_GEMINI_*`
- Codex thinking levels: `CLIPROXY_CODEX_THINKING_*`
- Preset: `CLIPROXY_PRESET` (claude by default)

After editing `.cliproxy.env`, run:

```zsh
source /path/to/cliproxy-config/.cliproxy.zsh
```
