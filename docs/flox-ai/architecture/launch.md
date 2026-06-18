# Launch

`flox-ai launch <agent>` runs an AI agent with the active environment's
fragments injected, then gets out of the way. It is the endpoint the TUI's
launch action calls, and a CLI command in its own right.

`internal/launch` holds a small registry (`launch.Supported`) and dispatches
by agent name. Two agents are registered.

## claude

`flox-ai launch claude` execs the Claude Code CLI (via `syscall.Exec`,
replacing the flox-ai process) with the environment's fragments injected
through `CLAUDE_CONFIG_DIR`. Arguments after `--` are forwarded to claude
verbatim; a single leading `--` delimiter is stripped (it is the conventional
separator and would otherwise be passed on as a positional).

This is the same wiring the activation hook sets up, exposed as an explicit
command — see [system-context.md](system-context.md).

## agent-deck

`flox-ai launch agent-deck` runs the Agent Deck terminal session manager with
a flox-managed, per-environment configuration. On every launch it:

- seeds an agent-deck `config.toml` under
  `$FLOX_ENV_PROJECT/.flox/cache/flox-ai/agents/agent-deck/`, copying the
  user's existing agent-deck config (from `$XDG_CONFIG_HOME/agent-deck`,
  `~/.config/agent-deck`, or legacy `~/.agent-deck`) when present;
- forces the deck's claude command to `flox-ai launch claude --`, so every
  session Agent Deck spawns runs back through flox-ai and inherits this
  environment's fragments;
- isolates the deck per environment via `AGENT_DECK_HOME` (a flox patch to
  agent-deck makes it override the `XDG_*` base dirs) plus a stable,
  per-config-dir tmux socket, so decks in different environments do not share
  state or collide. `AGENT_DECK_HOME` is used instead of overriding
  `XDG_CONFIG_HOME`/`XDG_DATA_HOME` because the deck's tmux server propagates
  its environment to every pane; hijacking `XDG_*` would leak the deck home
  into those panes and break unrelated programs.

`RunDeck` (in `internal/launch/agentdeck.go`) implements this; `go-toml/v2`
parses and rewrites the config.

## Why launch matters here

Agent Deck is why flox-ai shows up "inside" another tool: a deck session is a
claude session run through flox-ai. Supporting it in the TUI was a matter of
listing it in the agent picker (the registry already exposed it) and giving it
proper display and launch copy ([development/history.md](
../development/history.md)). claude remains the default selection.

The full per-flag behavior of `launch` is in the package README
(`.flox/pkgs/flox-ai/README.md`).
