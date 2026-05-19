# CodeBurn

Ready-to-use [CodeBurn](https://github.com/getagentseal/codeburn)
environment. CodeBurn is an interactive TUI dashboard that
shows where your AI coding tokens go — by task type, model,
tool, project, and provider.

Everything runs locally. No wrapper, no proxy, no API
keys. CodeBurn reads session data directly from disk and
prices every call using
[LiteLLM](https://github.com/BerriAI/litellm).

## Quick start

Include in your manifest:

```toml
[include]
environments = ["flox/codeburn"]
```

Or activate directly:

```bash
flox activate -r flox/codeburn
codeburn
```

## What it provides

- `codeburn` — interactive TUI dashboard and CLI

## Commands

| Command | Description |
| ------- | ----------- |
| `codeburn` | Interactive dashboard (default: 7 days) |
| `codeburn today` | Today's usage |
| `codeburn month` | This month's usage |
| `codeburn report -p 30days` | Rolling 30-day window |
| `codeburn status` | Compact one-liner (today + month) |
| `codeburn export` | CSV with today, 7 days, 30 days |
| `codeburn optimize` | Find waste, get copy-paste fixes |
| `codeburn compare` | Side-by-side model comparison |
| `codeburn yield` | Productive vs reverted/abandoned spend |
| `codeburn models` | Per-model token + cost table |

## Supported providers

CodeBurn auto-detects sessions from 20+ AI coding tools,
including Claude Code, Claude Desktop, Codex (OpenAI),
Cursor, cursor-agent, Cline, Gemini CLI, GitHub Copilot,
OpenCode, OpenClaw, Kiro, Roo Code, KiloCode, Qwen, Kimi,
Goose, Antigravity, Crush, and more.

Use `--provider <name>` on any command to scope a single
provider, e.g. `codeburn report --provider claude` or
`codeburn today --provider codex`.

## Configuration

`CLAUDE_CONFIG_DIRS` — colon-separated list of Claude
config dirs to merge across multiple Claude profiles,
e.g. `~/.claude-work:~/.claude-personal`.

## See also

- [codeburn-demo](../codeburn-demo/) — interactive
  demo with banner
- [Upstream repo](https://github.com/getagentseal/codeburn)
- [Provider docs](https://github.com/getagentseal/codeburn/tree/main/docs/providers)
