# Caveman

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fcaveman%2Fdevcontainer.json)

Claude Code environment with the
[caveman](https://github.com/JuliusBrussee/caveman)
plugin pre-installed.

Ultra-compressed communication mode that cuts ~75%
of tokens while keeping full technical accuracy.

## Quick start

Include in your manifest:

```toml
[include]
environments = ["flox/caveman"]
```

## What it provides

Everything from [claude](../claude/) plus:

- `claude-code-plugin-caveman` -- the caveman plugin
  with 7 skills:
  - `caveman` -- the headline compression mode
  - `caveman-commit` -- terse commit messages
  - `caveman-review` -- terse PR review comments
  - `caveman-compress` -- compress markdown memory
    files (e.g. `CLAUDE.md`, todo lists)
  - `caveman-stats` -- show real token usage and
    estimated savings for the active session
  - `caveman-help` -- quick-reference card
  - `cavecrew` -- decision guide for delegating
    to caveman-style subagents

A SessionStart hook activates caveman mode on every
session, and a UserPromptSubmit hook recognizes
`/caveman lite|full|ultra|wenyan-lite|wenyan-full|wenyan-ultra`
to switch intensity.

Node.js and Python are bundled inside the plugin,
so the hooks and the `caveman-compress` scripts run
without requiring the consumer env to install
either runtime.

## Usage

After `flox activate`, start Claude Code and type
`/caveman` (or just say "talk like caveman"). Switch
intensity with `/caveman ultra`. Deactivate with
"stop caveman" or "normal mode".

## See also

- [caveman-demo](../caveman-demo/) -- interactive
  demo with welcome banner
- [claude](../claude/) -- the base Claude Code
  environment this builds on
