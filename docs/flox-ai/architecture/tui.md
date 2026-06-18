# The TUI

`internal/tui` is a Bubble Tea v2 application ([ADR 0001](
../decisions/0001-bubbletea-v2-tui.md)). It follows the Elm-style
model/update/view split: `model.go` holds state, `update.go` handles
messages, `view.go` renders. It requires a Flox environment
([ADR 0007](../decisions/0007-require-flox-environment.md)) and a Nerd
Font ([ADR 0002](../decisions/0002-nerd-font-required.md)).

## Layout

A top band leads with the flox bolt mark (traced from the SVG into
quadrant block-art), the brand line and agent selector, and the search
box; below it a master/detail body lists catalog fragments with a detail
pane; a context-aware footer shows the active shortcuts. The header
agent selector switches the launch target.

## Core flows

- **Browse / search** — the embedded catalog with `#tag` autocomplete
  and a top-picks/installed default list.
- **Install / uninstall** — stage changes, then apply; apply runs
  `flox install` / `flox uninstall` against the active environment,
  showing one gray in-place line per change.
- **Switch agent** — the picker lists `launch.Supported` (claude,
  agent-deck); claude is the default selection.
- **Theme** — a searchable `bubbletint` picker with dark/light filtering
  and family siblings; the choice persists to a config file and the UI
  auto-detects the terminal background.
- **Upgrade** — `U` checks managed packages in the background and offers
  from→to upgrades.
- **Launch** — a confirmation, then exec claude or `RunDeck` for
  agent-deck.

## The review report

`R` runs the review:

1. `doctor.Probe()` checks tool availability in-process.
2. If tools are missing, an install prompt lists the `flox/<tool>`
   packages and installs them into the active environment on confirm.
3. `audit.Run(IncludeRaw: true)` scores each present skill/agent.
4. The result renders as a four-pane sliding miller view — skills →
   checks → findings → raw — with two full panes visible and ancestors
   collapsed to slivers ([ADR 0006](
   ../decisions/0006-four-pane-review-report.md)). `h`/`l` move focus,
   `j`/`k` move within a pane, rows are clickable.

## Startup splash

On launch the flox mark assembles, winks once, then explodes into
dissolving particles before the UI appears (~2s, skippable). The
background upgrade check starts during the splash but is held until it
finishes.

## Mouse and theming details

- `bubblezone/v2` marks clickable regions inline; `View` wraps the
  render in `zone.Scan`. Markers are zero-width to Lipgloss.
- Light/dark adaptation uses `BackgroundColorMsg.IsDark()` and
  `compat.AdaptiveColor`; a chosen theme flips to its light/dark sibling
  when the terminal background changes.

## Testability

The TUI calls the engine behind an `Auditor` interface
(`DoctorTools` + `Audit`); tests inject a fake that returns canned
results, so UI tests do not run external tools.
