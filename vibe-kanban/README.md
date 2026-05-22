# Vibe Kanban

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fvibe-kanban%2Fdevcontainer.json)

Ready-to-use [Vibe Kanban](https://github.com/BloopAI/vibe-kanban)
environment. Vibe Kanban is a kanban-style task manager that
lets you plan work as issues and execute it with coding
agents (Claude Code, Codex, Gemini CLI, Amp, ...).

> **Note:** Vibe Kanban is sunsetting. See the
> [announcement](https://www.vibekanban.com/blog/shutdown).
> The latest binaries are still served from the upstream
> CDN; this environment pins a known-good release.

## Quick start

Include in your manifest:

```toml
[include]
environments = [{ remote = "flox/vibe-kanban" }]
```

Or activate directly:

```bash
flox activate -r flox/vibe-kanban
vibe-kanban
```

Then open the printed URL in your browser.

## What it provides

- `vibe-kanban` — the kanban app (web server + UI)
- `vibe-kanban-mcp` — MCP server for coding-agent
  integration
- `vibe-kanban-review` — diff review CLI

The wrapped binaries have `git` and `nodejs` on their
`PATH`, which is what vibe-kanban shells out to when it
spawns work for coding agents.

## Configuration

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `BACKEND_PORT` | `13456` | Port the web UI listens on |
| `PREVIEW_PROXY_PORT` | `13457` | Port the preview proxy listens on |
| `VIBE_KANBAN_CACHE` | `$FLOX_ENV_CACHE/vibe-kanban` | Cache root |
| `XDG_DATA_HOME` | `$VIBE_KANBAN_CACHE/data` | App data dir (sqlite + config) |

To bring your own coding agent (e.g. Claude Code), include
its environment alongside this one:

```toml
[include]
environments = [
  "flox/vibe-kanban",
  "flox/claude",
]
```

## See also

- [vibe-kanban-demo](../vibe-kanban-demo/) — interactive
  demo with banner and Claude Code preinstalled
- [Upstream repo](https://github.com/BloopAI/vibe-kanban)
- [Shutdown announcement](https://www.vibekanban.com/blog/shutdown)
