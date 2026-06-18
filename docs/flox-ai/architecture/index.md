# Architecture

What the flox-ai system is and why. Start with the system context to
see how the pieces spread across an environment, then drill into the
package internals.

| Doc | What it covers |
| ------------------------------------ | -------------- |
| [system-context.md](system-context.md) | Why flox-ai is "everywhere": the binary in every env, activation wiring, fragments, the catalog, the website, the TUI, launch, and the audit engine |
| [overview.md](overview.md) | The Go package layout: commands, internal packages, and how they relate |
| [audit-engine.md](audit-engine.md) | The absorbed scoring engine: dimensions, the tool ensemble, findings, and raw output |
| [tui.md](tui.md) | The Bubble Tea TUI: model/update/view, the catalog browser, theming, the splash, and the four-pane review report |

For the significant choices behind this architecture, see the
[decision records](../decisions/README.md).
