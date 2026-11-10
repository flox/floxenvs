# graphify-demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fgraphify-demo%2Fdevcontainer.json)

Full [graphify](https://github.com/Graphify-Labs/graphify)
demo environment with common commands in its description.

For a minimal environment to include in your own
project, see [graphify](../graphify/) or use
`flox/graphify` on FloxHub.

## Quick start

```bash
flox activate -r flox/graphify-demo
```

The graphify skill is pre-installed via
`agent-stacks/agent-plugin-graphify-labs-graphify`,
from the base environment.

Run `flox-agent launch claude` to start Claude Code
with this environment's skills and rules injected. In
any directory, type:

```text
/graphify-labs-graphify:graphify .
```

Or use the CLI directly:

```bash
graphify .
```

## What this demo includes

- Everything from the `graphify` base environment:
  Python 3.11, the `graphify` CLI, the graphify skill
  (`agent-stacks/agent-plugin-graphify-labs-graphify`),
  Claude Code and `flox-agent`

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
environments = [{ remote = "flox/graphify" }]
```

This gives you Python, `graphify`, the graphify skill,
Claude Code and the `flox-agent` launcher with sane
defaults; run `flox-agent launch claude` to use the
skill.
Override vars in your own manifest as needed.
