# symphony-demo

Interactive [Symphony](https://github.com/openai/symphony)
demo environment. Starts the Phoenix dashboard with an
in-memory tracker by default, switches to a Linear
tracker when `LINEAR_API_KEY` is set.

For a minimal environment to include in your own
project, see [symphony](../symphony/) or use
`flox/symphony` on FloxHub.

## Quick start

```bash
flox activate -r flox/symphony-demo --start-services
```

Then open the dashboard:

```
http://localhost:14000
```

## What this demo includes

- Everything from the `symphony` base environment
- `gum` for styled terminal output
- Banner showing dashboard URL, active tracker,
  codex binary, and workspace root

## Tracker selection

| `LINEAR_API_KEY` | Tracker  | Behaviour                          |
| ---------------- | -------- | ---------------------------------- |
| unset (default)  | `memory` | Empty dashboard, no tickets        |
| set              | `linear` | Polls your Linear workspace        |

To run the Linear-driven demo:

```bash
export LINEAR_API_KEY=lin_api_...
flox activate -r flox/symphony-demo --start-services
```

The `WORKFLOW.md` is regenerated on every activation
based on the current value of `LINEAR_API_KEY`.

## Services

| Service            | URL                       |
| ------------------ | ------------------------- |
| Symphony dashboard | <http://localhost:14000>  |

```bash
flox services start             # start symphony
flox services stop              # stop symphony
flox services status            # check status
flox services logs symphony     # view logs
```

## Using the minimal version

If you don't need the demo experience, include the
minimal environment in your own manifest:

```toml
[include]
environments = ["flox/symphony"]
```

This gives you Symphony with sane defaults. Override
`SYMPHONY_PORT` or set `LINEAR_API_KEY` in your own
manifest as needed.
