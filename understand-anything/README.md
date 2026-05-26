# understand-anything

Claude Code environment with the
[Understand-Anything](https://github.com/Lum1104/Understand-Anything)
plugin pre-wired through `claude-managed`.

Understand-Anything turns any codebase into an interactive
knowledge graph you can explore, search, and ask questions
about. The plugin ships eight slash commands:

- `/understand` -- build the knowledge graph for a project
- `/understand-chat` -- ask questions about the graph
- `/understand-diff` -- analyze a diff against the graph
- `/understand-domain` -- extract business domain flows
- `/understand-explain` -- deep-dive on a file or function
- `/understand-knowledge` -- ingest a Karpathy-style wiki
- `/understand-onboard` -- generate an onboarding guide
- `/understand-dashboard` -- launch the interactive viewer

## Quick start

Activate directly:

```bash
flox activate -r flox/understand-anything
```

Then start Claude Code and run:

```text
/understand .
```

The first `/understand` invocation runs `pnpm install` and
builds `packages/core` inside the cached plugin tree -- this
takes a couple of minutes because of the tree-sitter native
deps. Set `UA_PREBUILD = "1"` (see below) to do this at
activation time instead.

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = [{ remote = "flox/understand-anything" }]
```

## What it provides

Everything from [claude](../claude/) plus:

| Package    | Description                                  |
| ---------- | -------------------------------------------- |
| `nodejs_22` | Required by the plugin's TS skill scripts  |
| `pnpm_10`   | Builds `@understand-anything/core`         |
| `python3`   | Runs the `.py` skill scripts (merge graphs) |
| `git`       | Clones the plugin source on first activate |
| `jq`        | Used by claude-managed and the skill setup |

The upstream repo is cloned into
`$FLOX_ENV_CACHE/understand-anything/repo` on first
activation and pinned to `UA_VERSION`. The plugin's
`understand-anything-plugin/` subdir is registered with
`claude-managed` so the `claude` wrapper picks it up via
`--plugin-dir` automatically.

## Configuration variables

| Variable      | Default                                                 | Description |
| ------------- | ------------------------------------------------------- | ----------- |
| `UA_REPO_URL` | `https://github.com/Lum1104/Understand-Anything.git`    | Upstream git URL |
| `UA_VERSION`  | `v2.7.3`                                                | Pinned release tag |
| `UA_PREBUILD` | `0`                                                     | Set `"1"` to build `packages/core` during activate |

Override in your own manifest before `[include]`-ing this
environment, e.g. to pin a different upstream:

```toml
[include]
environments = [{ remote = "flox/understand-anything" }]

[vars]
UA_VERSION  = "v2.5.0"
UA_PREBUILD = "1"
```

## Data directory

The plugin source and its `node_modules` live under
`$FLOX_ENV_CACHE/understand-anything/repo`. Per-project
analysis output lands in `.understand-anything/` inside the
target repository (the same convention the upstream uses
for the `~/.understand-anything-plugin` install).

To start fresh:

```bash
rm -rf "$FLOX_ENV_CACHE/understand-anything"
rm -f  "$HOME/.understand-anything-plugin"
```

## See also

For a styled demo with a welcome banner and the slash
commands cheat-sheet, see
[understand-anything-demo](../understand-anything-demo/).
