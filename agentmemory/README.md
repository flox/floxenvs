# agentmemory

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fagentmemory%2Fdevcontainer.json)

Minimal [agentmemory](https://github.com/rohitg00/agentmemory)
environment. Include it in your own manifest to get
Claude Code wired up with the agentmemory plugin plus
the matching REST/MCP backend running as a flox
service on port `3111`.

agentmemory is a persistent memory system for AI coding
agents: it captures tool usage, compresses observations,
and injects relevant context at the start of every new
Claude Code session.

## Quick start

Activate directly:

```bash
flox activate -r flox/agentmemory --start-services
```

The first activation downloads the
`@agentmemory/agentmemory` npm package into the per-env
cache and starts the backend on
[`http://localhost:3111`](http://localhost:3111).

Then open Claude Code in any directory and use the
agentmemory skills (`/recall`, `/remember`, `/handoff`,
`/recap`, etc.) — hooks fire automatically.

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/agentmemory"]
```

## What is included

| Package | Description |
| ------- | ----------- |
| `flox/claude-code` | Claude Code CLI |
| `flox/flox-ai` | Plugin discovery + config assembly |
| `flox/claude-code-plugin-agentmemory` | Plugin (13 hooks, 8 skills, MCP) |
| `nodejs_20` | Runtime for the REST backend |

The plugin tree lands under
`$FLOX_ENV/share/claude-code/plugins/agentmemory/` with
Node.js bundled as `bin/node` + `bin/npx` so hook
scripts and the MCP shim don't require nodejs on the
consumer's PATH.

## Services

| Service | Description |
| ------- | ----------- |
| `agentmemory` | REST + MCP backend (port `3111`) via |
| | `npx @agentmemory/agentmemory@$AGENTMEMORY_VERSION` |

Start it:

```bash
flox services start            # start agentmemory
flox services stop             # stop agentmemory
flox services status           # check status
flox services logs agentmemory # view logs
```

SQLite state and the npm cache live under
`$FLOX_ENV_CACHE/agentmemory/`.

## Environment variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `AGENTMEMORY_URL` | `http://localhost:3111` | REST endpoint hooks talk to |
| `AGENTMEMORY_INJECT_CONTEXT` | `true` | Injects context on SessionStart |
| `AGENTMEMORY_VERSION` | `0.9.20` | Pinned server version for `npx` |
| `AGENTMEMORY_SECRET` | _(unset)_ | Bearer token sent to the REST endpoint |

Override in your own manifest:

```toml
[include]
environments = ["flox/agentmemory"]

[vars]
AGENTMEMORY_URL = "https://agentmemory.example.com"
AGENTMEMORY_SECRET = "redacted"
```

## Data directory

State (SQLite, npm cache) lives in
`$FLOX_ENV_CACHE/agentmemory/`.

To start fresh:

```bash
rm -rf "$FLOX_ENV_CACHE/agentmemory"
```

## See also

For a styled demo with a sample walkthrough, see
[agentmemory-demo](../agentmemory-demo/).
