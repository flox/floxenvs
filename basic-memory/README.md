# Basic Memory

Ready-to-use [Basic Memory](https://github.com/basicmachines-co/basic-memory)
environment — a local-first knowledge graph backed by Markdown
notes, exposed as an MCP server for Claude Code, Cursor, ChatGPT,
and other MCP clients.

## Quick start

Include in your manifest:

```toml
[include]
environments = ["flox/basic-memory"]
```

## What it provides

- `basic-memory` — the CLI
- `bm` — short alias for `basic-memory`

Both commands resolve the same Python entry point.

## Configuration

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `BASIC_MEMORY_CONFIG_DIR` | `~/.basic-memory` | Per-user state dir |
| `FASTEMBED_CACHE_PATH` | `<data>/fastembed_cache` | ONNX model cache |

## Semantic search

Bundled — `fastembed` and `sqlite-vec` are included in the Nix
closure. The first time you enable semantic search,
`fastembed` downloads the embedding model into
`FASTEMBED_CACHE_PATH`.

## Using with Claude Code

The minimal env exposes the CLI. To wire it as an MCP server for
Claude Code, either:

1. Use the demo env (`flox/basic-memory-demo`), which composes
   this env with `flox/claude` and writes a project-scope
   `.mcp.json`.
2. Or wire manually: `claude mcp add basic-memory -- basic-memory mcp`.

## See also

- [basic-memory-demo](../basic-memory-demo/) — interactive demo
  with Claude Code MCP wiring
- [basic-memory upstream](https://github.com/basicmachines-co/basic-memory)
