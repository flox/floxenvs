# agentmemory

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fagentmemory%2Fdevcontainer.json)

Minimal [agentmemory](https://github.com/rohitg00/agentmemory)
environment. Include it in your own manifest to get
Claude Code, the `flox-agent` launcher and the agentmemory
plugin, plus the matching REST/MCP backend running as a
flox service on port `3111`. Run `flox-agent launch claude`
to start Claude Code with the agentmemory skills, hooks and
MCP server loaded.

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
cache, fetches the pinned iii engine it runs on, and starts
the backend on
[`http://localhost:3111`](http://localhost:3111).

Then, in any directory, run `flox-agent launch claude` to
start Claude Code with this environment's skills and rules
injected. Use the
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
| `flox/flox-agent` | Launcher that loads the plugin into Claude Code |
| `agent-stacks/agent-plugin-agentmemory` | Plugin (hooks, 17 skills, MCP) |
| `nodejs_20` | Runtime for the REST backend |

The plugin tree lands under
`$FLOX_ENV/share/agent-plugins/agentmemory/` with
Node.js bundled as `bin/node` so hook scripts and the
MCP bridge don't require nodejs on the consumer's PATH.

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

The service runs non-interactively, skipping the upstream
CLI's setup prompts. `flox services stop` also stops the iii
engine the backend starts.

Check that it is serving:

```bash
curl -H "Authorization: Bearer $AGENTMEMORY_SECRET" \
  http://localhost:3111/agentmemory/health
```

The server reads its LLM and embedding settings from the
environment it starts in (for example `ANTHROPIC_API_KEY`),
not from `~/.agentmemory/.env`. Set them in `[vars]` or your
shell before starting the service.

## Environment variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `AGENTMEMORY_URL` | `http://localhost:3111` | REST endpoint hooks talk to |
| `AGENTMEMORY_INJECT_CONTEXT` | `true` | Injects context on SessionStart |
| `AGENTMEMORY_VERSION` | `0.9.30` | Pinned server version for `npx` |
| `AGENTMEMORY_SECRET` | _(generated)_ | Bearer token for the REST endpoint. Unless set, the activation hook generates one in the env cache and exports it for the service and Claude Code |

Override in your own manifest:

```toml
[include]
environments = ["flox/agentmemory"]

[vars]
AGENTMEMORY_URL = "https://agentmemory.example.com"
AGENTMEMORY_SECRET = "redacted"
```

## Data directory

Everything the service keeps lives in
`$FLOX_ENV_CACHE/agentmemory/`:

| Path | Contents |
| ---- | -------- |
| `data/` | Memory state |
| `home/.agentmemory/` | The upstream CLI's runtime files: API secret, engine state, pidfiles, preferences |
| `npm/`, `npm-prefix/` | npm cache and prefix for `npx` |

The service runs the CLI with `HOME` pointed at `home/`,
so it never touches your own `~/.agentmemory/` and each
project gets its own state. Only one agentmemory backend
can hold port `3111` at a time.

To start fresh, stop the service and run:

```bash
rm -rf "$FLOX_ENV_CACHE/agentmemory"
```

## See also

For a styled demo with a sample walkthrough, see
[agentmemory-demo](../agentmemory-demo/).
