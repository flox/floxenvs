# graphify-demo

Full [graphify](https://github.com/safishamsi/graphify)
demo environment with a styled terminal banner showing
the common commands.

For a minimal environment to include in your own
project, see [graphify](../graphify/) or use
`flox/graphify` on FloxHub.

## Quick start

```bash
flox activate -r flox/graphify-demo
```

One-time setup — register the Claude Code skill:

```bash
graphify install
```

Then build a graph from any folder:

```bash
graphify .
```

Open Claude Code in any directory and type:

```text
/graphify .
```

## What this demo includes

- Everything from the `graphify` base environment
  (Python 3.11, `graphify` CLI, Claude Code)
- `gum` for the styled terminal banner
- Banner with common commands and the in-Claude trigger

## Commands cheat sheet

| Command | Description |
| ------- | ----------- |
| `graphify .` | Build a graph from the current directory |
| `graphify ./raw --mode deep` | Richer INFERRED edge extraction |
| `graphify ./raw --update` | Incremental re-extract on changes |
| `graphify ./raw --watch` | Auto-rebuild as files change |
| `graphify add <url>` | Fetch URL, save to `./raw`, update graph |
| `graphify query "<question>"` | BFS traversal query |
| `graphify path "A" "B"` | Shortest path between concepts |
| `graphify explain "<node>"` | Plain-language explanation |
| `graphify hook install` | Install post-commit git hook |

Outputs land under `graphify-out/`:

| File | Description |
| ---- | ----------- |
| `graph.html` | Interactive vis.js graph |
| `obsidian/` | Open as an Obsidian vault |
| `wiki/` | Wikipedia-style articles per cluster |
| `GRAPH_REPORT.md` | God nodes and surprising connections |
| `graph.json` | Persistent graph (incremental cache) |

## Using the minimal version

If you don't need the demo experience, include the
minimal environment in your own manifest:

```toml
[include]
environments = ["flox/graphify"]
```

This gives you Python, `graphify`, and Claude Code with
sane defaults. Override vars in your own manifest as
needed.
