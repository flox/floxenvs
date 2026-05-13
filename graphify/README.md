# graphify

Minimal [graphify](https://github.com/safishamsi/graphify)
environment. Include it in your own manifest to get
Python 3.11, the `graphify` CLI, and Claude Code with
sane defaults.

graphify is a Claude Code skill that turns any folder of
code, docs, papers, or images into a queryable knowledge
graph.

## Quick start

Activate directly:

```bash
flox activate -r flox/graphify
```

The `/graphify` SKILL.md ships with the env (via
`flox/skills-graphify`) under
`$FLOX_ENV/share/claude-code/skills/graphify/`. To have
Claude Code auto-discover it, compose this env with
`flox/claude` (which provides `claude-managed`):

```toml
[include]
environments = ["flox/graphify", "flox/claude"]
```

Otherwise run `graphify install` manually.

Open Claude Code in any directory and type:

```text
/graphify .
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = ["flox/graphify"]
```

Then customize vars in your own manifest to override
defaults.

## What is included

- Python 3.11 with `graphifyy` installed in a venv
- Claude Code CLI (the skill host)
- `flox/skills-graphify` — bundled `/graphify` SKILL.md
- Git, curl, and build tools for tree-sitter native deps

## Usage

```bash
graphify .                          # build graph for current directory
graphify ./raw --mode deep          # richer INFERRED edge extraction
graphify ./raw --update             # incremental re-extract
graphify query "what connects X?"   # query the graph
graphify path "Module" "Database"   # shortest path between concepts
graphify add https://example.com/x  # fetch URL and merge into graph
graphify ./raw --watch              # auto-rebuild on file changes
graphify hook install               # install post-commit git hook
```

Full output lives under `graphify-out/` in the target
folder, including:

| File | Description |
| ---- | ----------- |
| `graph.html` | Interactive vis.js graph |
| `obsidian/` | Open as an Obsidian vault |
| `wiki/` | Wikipedia-style articles per cluster |
| `GRAPH_REPORT.md` | God nodes, surprising connections |
| `graph.json` | Persistent graph |
| `cache/` | SHA256 cache for incremental runs |

## Services

| Service | Description |
| ------- | ----------- |
| `graphify-watch` | Watches `$GRAPHIFY_PROJECT_ROOT` and rebuilds the graph on code changes |
| `graphify-mcp` | MCP stdio server backed by `graphify-out/graph.json` (waits for the file to appear) |

Start them:

```bash
flox services start
# or activate with services already running:
flox activate --start-services
```

`graphify-mcp` blocks until `graphify-watch` (or a
manual `graphify <root>` run) produces `graph.json`,
so the natural order is just `flox services start`.

## Environment variables

| Variable | Description |
| -------- | ----------- |
| `GRAPHIFY_INSTALL_PACKAGE` | PyPI spec installed in the venv (default `graphifyy[mcp,watch]`) |
| `GRAPHIFY_PROJECT_ROOT` | Folder graphify watches and serves (default: the dir containing `.flox/`, i.e. `$FLOX_ENV_PROJECT`) |

Pin a version or point at a different folder by
overriding in your own manifest:

```toml
[include]
environments = ["flox/graphify"]

[vars]
GRAPHIFY_INSTALL_PACKAGE = "graphifyy[mcp,watch]==0.1.14"
GRAPHIFY_PROJECT_ROOT = "/abs/path/to/my/repo"
```

## Data directory

The Python venv lives in `$FLOX_ENV_CACHE/python`.

To start fresh:

```bash
rm -rf "$FLOX_ENV_CACHE/python"
```

## See also

For a styled demo with a sample corpus, see
[graphify-demo](../graphify-demo/).
