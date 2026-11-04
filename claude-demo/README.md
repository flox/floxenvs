# Claude Code Demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fclaude-demo%2Fdevcontainer.json)

Interactive demo of the [claude](../claude/) environment: Claude
Code started through flox-agent, with one agent plugin installed
to show it being loaded.

## Quick start

```bash
flox activate -r flox/claude-demo
claude plugin list
claude
```

`claude plugin list` shows `flox` as a session-only plugin,
loaded by `flox-agent launch claude`.

## What it provides

Everything from [claude](../claude/) plus:

- `agent-stacks/agent-plugin-flox` — the Flox agent plugin,
  which teaches Claude Code to work with Flox environments
- `gum` — styled terminal UI
- Welcome banner on activate

## See also

- [claude](../claude/) — minimal environment for `[include]`
