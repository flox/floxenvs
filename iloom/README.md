# iloom

Ready-to-use [iloom](https://github.com/iloom-ai/iloom-cli)
environment. iloom is a developer workflow system that runs
Claude Code in isolated git worktrees and persists the AI's
analysis, plans, and decisions to your issue tracker (GitHub,
Linear, Jira, or BitBucket).

## Quick start

Include in your manifest:

```toml
[include]
environments = ["flox/iloom"]
```

Or activate directly:

```bash
flox activate -r flox/iloom
gh auth login
il start <issue-number>
```

## What it provides

- `iloom` / `il` — the iloom CLI (both names invoke the
  same binary)
- `gh` — GitHub CLI, used by iloom for issue-tracker
  authentication

`iloom` shells out to `git` at runtime; `git` is wrapped
into the binary's `PATH` so it works regardless of the host
environment.

## Bring your own coding agent

iloom drives Claude Code by default. Include the
[`flox/claude`](../claude/) environment alongside this one
to get a managed Claude CLI:

```toml
[include]
environments = [
  "flox/iloom",
  "flox/claude",
]
```

Other agents are supported by upstream — see the iloom
[command reference](https://github.com/iloom-ai/iloom-cli#command-reference).

## Configuration

iloom reads its configuration from `.iloom/` inside each
project and from environment variables. Notable ones:

| Variable | Purpose |
| -------- | ------- |
| `ILOOM_DEBUG` | Set to `true` for verbose logging |
| `ILOOM_VERSION_OVERRIDE` | Force a specific reported version |
| `DOTENV_FLOW_NODE_ENV` | Which `.env` profile to load |

Run `il telemetry off` to disable anonymous usage
analytics.

## See also

- [iloom-demo](../iloom-demo/) — interactive demo with a
  styled banner
- [Upstream repo](https://github.com/iloom-ai/iloom-cli)
- [VS Code extension](https://marketplace.visualstudio.com/items?itemName=iloom-ai.iloom-vscode)
