# graphify-demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fgraphify-demo%2Fdevcontainer.json)

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
  (Python 3.11, `graphify` CLI)
- The `flox-ai` launcher, which discovers skills under
  `$FLOX_ENV/share/claude-code/skills/` and injects them
  when you run `flox-ai launch claude` (you bring your
  own Claude Code install)
- `flox/skills-graphify` — ships the `/graphify` SKILL.md
  so Claude Code finds it once launched via `flox-ai`
- `gum` for the styled terminal banner

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

This gives you Python, `graphify`, and the `flox-ai`
launcher with sane defaults. Install Claude Code
yourself, then run `flox-ai launch claude` to use it.
Override vars in your own manifest as needed.
