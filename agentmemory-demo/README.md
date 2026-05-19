# agentmemory-demo

Interactive walkthrough for the [agentmemory](../agentmemory/)
environment. Wraps the minimal env with `gum` and prints
a styled banner explaining how to start the backend,
where the plugin is installed, and which Claude Code
commands the plugin contributes.

## Quick start

```bash
flox activate -r flox/agentmemory-demo --start-services
```

The activation hook prints the banner, the
`agentmemory` service runs in the background, and
`claude` is on PATH with the plugin wired up.

Try the plugin's skills inside Claude Code:

| Command | What it does |
| ------- | ------------ |
| `/recall` | Pull relevant memories for the current task |
| `/remember` | Save an insight to long-term memory |
| `/recap` | Summarise what happened in this session |
| `/handoff` | Hand the session off to another agent |
| `/forget` | Delete a memory by id or concept |
| `/commit-context` | Surface context around recent commits |
| `/commit-history` | Browse memories scoped to a commit |
| `/session-history` | Browse past sessions |

## See also

- [agentmemory](../agentmemory/) — the minimal base layer
- [Upstream project](https://github.com/rohitg00/agentmemory)
