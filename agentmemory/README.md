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
curl -H "Authorization: Bearer $(cat ~/.agentmemory/secret)" \
  http://localhost:3111/agentmemory/health
```

## Environment variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `AGENTMEMORY_URL` | `http://localhost:3111` | REST endpoint hooks talk to |
| `AGENTMEMORY_INJECT_CONTEXT` | `true` | Injects context on SessionStart |
| `AGENTMEMORY_VERSION` | `0.9.30` | Pinned server version for `npx` |
| `AGENTMEMORY_SECRET` | _(unset)_ | Bearer token for the REST endpoint; when unset, the server generates one in `~/.agentmemory/secret` and local hooks read it from there |

Override in your own manifest:

```toml
[include]
environments = ["flox/agentmemory"]

[vars]
AGENTMEMORY_URL = "https://agentmemory.example.com"
AGENTMEMORY_SECRET = "redacted"
```

## Data directory

Memory state (`data/`) and the npm cache live in
`$FLOX_ENV_CACHE/agentmemory/`.

The upstream CLI keeps its runtime files in
`~/.agentmemory/`: the pinned iii engine binary, the
generated API secret, pidfiles and preferences. The plugin
hooks look for the secret there, so it is left in place.

To start fresh:

```bash
rm -rf "$FLOX_ENV_CACHE/agentmemory"
```

This clears this environment's memories and npm cache but
leaves `~/.agentmemory/` alone, since other projects using
agentmemory share it. To reset that too, stop every
agentmemory service and remove it.

## See also

For a styled demo with a sample walkthrough, see
[agentmemory-demo](../agentmemory-demo/).
