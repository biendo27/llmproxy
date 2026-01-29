# LLMProxy (CLIProxyAPI wrapper)

LLMProxy is a small set of shell tools that make it easy to switch models and
routes for Claude Code (and other tools) using CLIProxyAPI. It works on Linux
and macOS, with a simple menu or one‑line commands.

---

## Quick start

1) **Clone the repo and go to the folder**

```zsh
git clone git@github.com:biendo27/llmproxy.git
cd llmproxy
```

2) **Run the setup wizard** (recommended)

```zsh
./llmproxy setup
```

It will:
- create `config/llmproxy.env` from the template
- offer to auto‑install missing tools
- optionally install/upgrade CLIProxyAPI and generate a local config
- add auto‑source to your shell rc (`~/.zshrc` on zsh)

3) **Reload your shell**

```zsh
source ~/.zshrc
```

4) **Open the menu**

```zsh
llmproxy
```

---

## First run notes (important)

- `llmproxy` works right after clone, but **/v1/models requires CLIProxyAPI running**.
- If you’re running the server locally, ensure `CLIPROXY_URL`/`CLIPROXY_KEY` in `config/llmproxy.env`
  match the server `api-keys` in your CLIProxyAPI config.
- If you only want official Claude (no proxy), run:
  ```zsh
  llmproxy off
  ```

---

## Prerequisites

Required:
- `zsh`
- `curl`
- `python3`

Optional (better UI):
- `fzf`

Install examples:

Linux (Ubuntu/Debian):
```zsh
sudo apt update && sudo apt install -y curl python3 fzf
```

macOS (Homebrew):
```zsh
brew install curl python fzf
```

---

## Daily usage (most common)

```zsh
llmproxy                     # open menu
llmproxy use codex            # switch preset (auto-sync to /v1/models)
llmproxy use <model>          # use a specific model id
llmproxy pick-model           # pick from /v1/models
llmproxy status               # show current status
```

Legacy alias:
```zsh
cliproxy ...                  # still works
```

---

## Switch proxy ↔ official Claude

Use your Claude subscription without proxy:

```zsh
llmproxy off      # use official Claude
llmproxy on       # enable proxy again
llmproxy toggle   # switch between the two
```

Persist default mode in `config/llmproxy.env`:

```zsh
export LLMPROXY_MODE="proxy"  # or "official"
```

Disable auto-sync if you want to pin models manually:

```zsh
export LLMPROXY_AUTO_SYNC="0"
```

---

## One‑time commands

```zsh
llmproxy setup     # wizard: env + deps + auto‑source (+ optional CLIProxyAPI install)
llmproxy install   # add auto‑source to shell rc
llmproxy fix       # auto‑install missing deps
llmproxy doctor    # check deps, server reachability, OS, mode
llmproxy sync-models claude   # sync preset models from /v1/models
```

Tip: after git clone, you can run `./llmproxy setup` directly from this folder
without touching your shell config first.
Note: setup only installs the CLIProxyAPI binary (Homebrew on macOS, installer script on Linux);
it does not start any background service.

---

## Files in this folder

- `config/llmproxy.env` - profiles, API keys, model defaults
- `config/llmproxy.env.example` - safe template (no real keys)
- `config/cliproxyapi-safe-defaults-config-template.yaml` - safe CLIProxyAPI config template
- `config/cliproxyapi-local-config.yaml` - local CLIProxyAPI config (generated, gitignored)
- `src/llmproxy-bootstrap-loader.zsh` - bootstrap loader
- `src/` - core modules (commands, UI, server control)
- `bin/llmproxy` - primary entrypoint
- `llmproxy` - root wrapper (calls bin/llmproxy)

---

## Documentation

- `docs/project-overview-pdr.md` - Product overview and requirements
- `docs/codebase-summary.md` - High-level repository summary
- `docs/code-standards.md` - Conventions used in this repo
- `docs/system-architecture.md` - Component and data flow overview
- `docs/project-roadmap.md` - Current milestones and roadmap

---

## CLIProxyAPI config (optional)

You only need a config if you **run the CLIProxyAPI server** yourself.
If you just use the menu and connect to an existing server, you can ignore it.

If you do run the server:
- start from `config/cliproxyapi-safe-defaults-config-template.yaml` or generate a local config via `./llmproxy setup`
- set `CLIPROXY_CONFIG` in `config/llmproxy.env` to point at your config
- make sure `CLIPROXY_URL` and `CLIPROXY_KEY` in `config/llmproxy.env` match it

---

## Run mode (direct vs background)

Default mode is **direct** (runs `./cli-proxy-api` with `--config` in foreground).

```zsh
llmproxy run-mode direct
llmproxy run-mode background
llmproxy run-mode background --persist
```

Background mode uses **systemd** on Linux and **launchd** on macOS.

### Linux (systemd)
```zsh
llmproxy systemd-install
llmproxy systemd-enable
```

### macOS (launchd)
```zsh
llmproxy launchd-install
llmproxy launchd-enable
```

### Cross-platform shortcut
```zsh
llmproxy background-install   # auto-detects OS
```

Upgrade binary:
```zsh
llmproxy upgrade
```

Backup binary:
```zsh
llmproxy backup
```

---

## macOS support

- `llmproxy upgrade` supports **darwin** (arm64/amd64)
- Background mode uses **launchd** (plist in `~/Library/LaunchAgents/`)

---

## Security (important)

- `config/llmproxy.env` contains API keys. **Do not publish** it in a public repo.
- This folder includes `.gitignore` to avoid committing secrets.
- If keys leak, rotate/revoke immediately.

---

## Troubleshooting

- **`llmproxy` not found**: run `./llmproxy setup` again, or manually add
  `source "/path/to/llmproxy/src/llmproxy-bootstrap-loader.zsh"` to your shell rc.
- **Server not reachable**: run `llmproxy doctor` to check URL/key.
- **Claude still shows API billing**: run `llmproxy off`, then restart Claude
  Code and login again.

---

## Model defaults

Defined in `config/llmproxy.env`:
- `CLIPROXY_CLAUDE_*`, `CLIPROXY_CODEX_*`, `CLIPROXY_GEMINI_*`
- Codex thinking levels: `CLIPROXY_CODEX_THINKING_*`
- Preset: `CLIPROXY_PRESET`

After editing `config/llmproxy.env`:
```zsh
source /path/to/llmproxy/src/llmproxy-bootstrap-loader.zsh
```
