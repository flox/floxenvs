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

Then register the Claude Code skill (one-time setup):

```bash
graphify install
```

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

## Environment variables

| Variable | Description |
| -------- | ----------- |
| `GRAPHIFY_INSTALL_PACKAGE` | PyPI spec installed in the venv (default `graphifyy`) |

Pin a version by setting:

```toml
[vars]
GRAPHIFY_INSTALL_PACKAGE = "graphifyy==0.1.14"
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
