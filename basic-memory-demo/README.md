# Basic Memory + Claude Code Demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fbasic-memory-demo%2Fdevcontainer.json)

Interactive demo combining
[Basic Memory](https://github.com/basicmachines-co/basic-memory)
with Claude Code. Activating this env writes a project-scope
`.mcp.json` so Claude Code automatically discovers basic-memory's
MCP tools.

## What you get

- `basic-memory` and `bm` from the
  [basic-memory](../basic-memory/) env
- The `flox-ai` launcher from the [claude](../claude/) env
- A pre-written `.mcp.json` wiring basic-memory into Claude Code

## Try it

This env ships the `flox-ai` launcher but not Claude Code itself.
First install Claude Code (e.g. `flox install flox/claude-code`)
or use your own install, then launch it with this env's skills and
rules injected:

```bash
cd basic-memory-demo
flox activate
flox-ai launch claude
```

Once Claude Code is running, ask it to:

- "Read note about X" — basic-memory's `read_note` tool fires
- "Build context from my notes about Y" — `build_context` tool
- "Add a new observation: ..." — `write_note` tool

Twenty-three MCP tools are exposed in total. See
`basic-memory --help` for the full surface.

## How the MCP wiring works

On activate the demo writes:

```json
{
  "mcpServers": {
    "basic-memory": {
      "command": "basic-memory",
      "args": ["mcp"]
    }
  }
}
```

Claude Code reads `.mcp.json` from the current working directory.
Because `basic-memory` is on PATH from the included env, the
command resolves without any global config. Run
`flox-ai launch claude` from a different directory and
basic-memory won't be wired — by design.

## Manual MCP smoke test

```bash
(
  printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"0"}}}'
  printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  sleep 2
) | basic-memory mcp 2>/dev/null \
  | grep -o '"name":"[^"]*"' | sort -u | wc -l
```

Expected: 23 (one per exposed tool).
