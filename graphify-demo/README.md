# graphify-demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fgraphify-demo%2Fdevcontainer.json)

Full [graphify](https://github.com/safishamsi/graphify)
demo environment with common commands in its description.

For a minimal environment to include in your own
project, see [graphify](../graphify/) or use
`flox/graphify` on FloxHub.

## Quick start

```bash
flox activate -r flox/graphify-demo
```

The `/graphify` skill is pre-installed via
`flox/skills-graphify` and auto-discovered by
`flox-ai` — no `graphify install` step needed.

First install Claude Code (e.g.
`flox install flox/claude-code`) or use your own
install, then run `flox-ai launch claude` to start it
with this environment's skills and rules injected. In
any directory, type:

```text
/graphify .
```

Or use the CLI directly:

```bash
graphify .
```

## What this demo includes

- Everything from the `graphify` base environment
  (Python 3.11, `graphify` CLI, Claude Code, `flox-agent`)
- The `flox-ai` launcher, which discovers the graphify
  skill and injects it when you run `flox-ai launch claude`.
  (`flox-agent` can't load this skill package yet.)
- `flox/skills-graphify` — ships the `/graphify` SKILL.md
  so Claude Code finds it once launched via `flox-ai`

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

This gives you Python, `graphify`, Claude Code and the
`flox-agent` launcher with sane defaults; run
`graphify install` to register the skill, then
`flox-agent launch claude`.
Override vars in your own manifest as needed.
