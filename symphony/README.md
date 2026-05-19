# symphony

Minimal [Symphony](https://github.com/openai/symphony)
environment with a Codex agent backend.

Include it in your own manifest to get the
`symphony` orchestrator and a `codex` binary, plus a
ready-to-run Phoenix LiveView dashboard.

## Quick start

Activate directly:

```bash
flox activate -r flox/symphony --start-services
```

Open the dashboard:

```text
http://localhost:14000
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = [{ remote = "flox/symphony" }]
```

## What is included

| Package | Description |
| ------- | ----------- |
| `flox/symphony` | OpenAI Symphony orchestrator |
| `flox/codex` | Codex coding agent backend |
| `git` | Git CLI for workspace ops |
| `bash` | Bash for hook + service scripts |

## Configuration

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `SYMPHONY_PORT` | `14000` | Phoenix dashboard port |
| `LINEAR_API_KEY` | _(unset)_ | Switch tracker from `memory` to `linear` |
| `CODEX_BIN` | _resolved_ | Codex binary path, set from `command -v codex` |

When `LINEAR_API_KEY` is empty, Symphony runs an
in-memory tracker — the dashboard is up but no
tickets flow through. Set `LINEAR_API_KEY` to switch
to a Linear-driven workflow.

## Services

Symphony runs as a background service:

```bash
flox services start            # start symphony
flox services stop             # stop symphony
flox services status           # check status
flox services logs symphony    # view logs
```

Workflow state, workspaces, and logs live under
`$FLOX_ENV_CACHE/symphony/`.

## See also

For a walkthrough with styled terminal output, see
[symphony-demo](../symphony-demo/).
