# Architecture

What the flox-ai system is and why. Start with the system context to
see how the pieces spread across an environment, then drill into the
package internals.

| Doc | What it covers |
| ------------------------------------ | -------------- |
| [system-context.md](system-context.md) | Why flox-ai is "everywhere": the binary in every env, activation wiring, fragments, the catalog, the website, the TUI, launch, and the audit engine |
| [overview.md](overview.md) | The Go package layout: commands, internal packages, and how they relate |
| [audit-engine.md](audit-engine.md) | The absorbed scoring engine: dimensions, the tool ensemble, findings, and raw output |
| [audit-tools.md](audit-tools.md) | The six external quality/security tools, the per-kind ensembles, weights, and the score fusion |
| [tui.md](tui.md) | The Bubble Tea TUI: model/update/view, the catalog browser, theming, the splash, and the four-pane review report |
| [launch.md](launch.md) | Launching agents: claude (exec) and Agent Deck (per-env isolated config + tmux socket) |

For the significant choices behind this architecture, see the
[decision records](../decisions/README.md).
