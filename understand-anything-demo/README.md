# understand-anything-demo

Full
[Understand-Anything](https://github.com/Lum1104/Understand-Anything)
demo environment with a styled banner showing the slash
commands cheat-sheet and `packages/core` pre-built so
`/understand` runs without a cold-start pnpm install.

For a minimal environment to include in your own project,
see [understand-anything](../understand-anything/) or use
`flox/understand-anything` on FloxHub.

## Quick start

```bash
flox activate -r flox/understand-anything-demo
```

Start Claude Code and run:

```text
/understand .
```

## What this demo includes

- Everything from the `understand-anything` base
  environment (Node 22, pnpm, Python 3, git, the cloned
  plugin checkout, and `flox-ai` registration)
- `UA_PREBUILD = "1"` so the activation hook compiles
  `packages/core` upfront — `/understand` is then ready
  the first time you invoke it
- `gum` for the styled welcome banner

## Commands cheat-sheet

| Command                  | Description                                |
| ------------------------ | ------------------------------------------ |
| `/understand .`          | Build a knowledge graph for the cwd        |
| `/understand --full`     | Force a full rebuild, ignore prior graph   |
| `/understand --auto-update` | Update graph automatically on commit    |
| `/understand-chat <q>`   | Ask a question against the graph           |
| `/understand-diff`       | Score the current diff for blast radius    |
| `/understand-domain`     | Extract business domains and flows         |
| `/understand-explain <p>` | Deep-dive on a file, function, or module  |
| `/understand-knowledge`  | Ingest a Karpathy-style LLM wiki           |
| `/understand-onboard`    | Generate an onboarding guide               |
| `/understand-dashboard`  | Launch the interactive web visualizer      |

Outputs land under `.understand-anything/` in the target
repo:

| File                              | Description                |
| --------------------------------- | -------------------------- |
| `knowledge-graph.json`            | Persistent graph           |
| `meta.json`                       | Commit hash + run metadata |
| `config.json`                     | Per-project config         |
| `intermediate/`                   | Per-batch scratch output   |

## Using the minimal version

If you don't need the demo experience, include the
minimal environment in your own manifest:

```toml
[include]
environments = [{ remote = "flox/understand-anything" }]
```

This gives you Node, pnpm, Python, git, and the
registered plugin without `gum` or the banner. Override
`UA_VERSION` or `UA_PREBUILD` in your own `[vars]` as
needed.
