# System context — why flox-ai is everywhere

flox-ai is connective tissue. It is a single Go binary, but it shows up
in many places because its job is to make a Flox environment's AI
fragments available to whatever agent you run. This page maps where it
appears and how the pieces connect.

## The binary, in every AI environment

`flox-ai` is built as a custom Nix package (`.flox/pkgs/flox-ai`,
`buildGoModule`) and installed into AI-enabled Flox environments. It is
one binary with subcommands (see [overview](overview.md)).

## Activation wiring — how it injects itself

An environment opts in by emitting flox-ai's shell code from its Flox
manifest hooks:

- `flox-ai setup-hook` emits on-activate code that sets
  `CLAUDE_CONFIG_DIR`, exports `FLOX_AI=1`, disables Claude's auto
  memory, puts `CLAUDE_CONFIG_DIR/bin` on PATH, and runs
  `rules/skills/agents/plugins clean` then `add` to (re)build the
  fragment symlinks.
- `flox-ai setup-profile` (bash/zsh/fish variants) emits profile code
  that re-exports PATH for interactive shells and registers cleanup.

The result: activating the environment makes its fragments visible to
the agent, and deactivating cleans up the managed symlinks.

## Fragments — the unit of content

Fragments live under `$FLOX_ENV/share/claude-code/` (the "share dir"):
`rules/`, `skills/`, `agents/`, and `plugins/`. `internal/discover`
scans them; `internal/symlinks` and `internal/plugins` manage the
symlinks and the plugin JSON into `CLAUDE_CONFIG_DIR`. `internal/doctor`
validates their frontmatter.

## The catalog and the website

The browsable catalog is data, not code-in-the-loop. The website
(`.website`) emits `ai-catalog.json`; flox-ai embeds a snapshot
(`internal/catalog`, `go:embed`) and the TUI browses it. Installing a
catalog entry runs `flox install <pkg>` into the active environment.

## The TUI

`flox-ai tui` is the browse/install/launch front end (see
[tui.md](tui.md)). It only runs inside a Flox environment
([ADR 0007](../decisions/0007-require-flox-environment.md)).

## Launch — claude and agent-deck

`internal/launch` knows two agents:

- `claude` — execs the Claude Code CLI with the environment's fragments
  injected via `CLAUDE_CONFIG_DIR`.
- `agent-deck` — a terminal session manager. flox-ai seeds an
  environment-isolated agent-deck config (its own data home and tmux
  socket) and points the deck's claude command at
  `flox-ai launch claude --`, so every session the deck spawns also runs
  through flox-ai and inherits the environment's fragments.

The TUI's agent picker lists whatever `launch.Supported` registers;
`claude` is the default selection.

## The audit engine

`flox-ai audit` (and the TUI's review report) score skills and agents
in-process via `internal/audit`, which orchestrates six external
quality tools. This engine was absorbed from a former standalone
`review-skills` binary ([ADR 0003](
../decisions/0003-absorb-audit-engine-in-process.md)). See
[audit-engine.md](audit-engine.md).

## How a request flows

```text
flox activate
  └─ setup-hook / setup-profile  (flox-ai emits shell wiring)
       └─ fragments symlinked into CLAUDE_CONFIG_DIR
flox-ai tui
  ├─ browse embedded catalog          (internal/catalog)
  ├─ install  → flox install <pkg>     (internal/tui → installer)
  ├─ review   → audit.Run per fragment (internal/audit, in-process)
  │              └─ doctor.Probe gates on tool availability
  └─ launch   → claude (exec) | agent-deck (RunDeck)   (internal/launch)
```
