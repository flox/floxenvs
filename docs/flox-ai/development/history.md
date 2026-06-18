# Design history

How flox-ai's TUI and audit reached their current shape. This narrative is
distilled from the per-feature design specs and implementation plans (kept in
`.plans/`, not committed). It complements the [decision records](
../decisions/README.md), which capture the individual choices.

## Foundation: the launch command (2026-06-16)

Before the TUI, flox-ai's AI config reached Claude Code only through the Flox
activation lifecycle — the hook and profile mutate the interactive shell to
point `CLAUDE_CONFIG_DIR` at an isolated dir, bridge keychain credentials,
symlink fragments, and drop a `claude` wrapper on PATH. The first design added
an explicit `flox-ai launch <agent>` command that injects that same config and
execs the agent without depending on shell mutation. This is the foundation
the TUI's launch action and Agent Deck build on (see
[architecture/launch.md](../architecture/launch.md)).

## The TUI, in layers

The TUI was designed and rebuilt in several passes, each its own spec:

1. **Initial design** — `flox-ai tui` as a Bubble Tea browser over a curated
   catalog of fragments: search, multi-select, install into the active
   environment, then launch. Built on top of the launch command.
2. **Restyle (v1)** — borrow proven patterns from dlvhdr's Bubble Tea apps
   (gh-dash, diffnav): a semantic theme, a context-aware help footer
   (`bubbles/help`), focus-aware borders, a selected-row highlight, Nerd-Font
   status pills, and a streaming spinner.
3. **Search-first redesign** — turn it into a search-engine-style, Vim-native
   browser: start on an empty search box, filter by text and `#tag` chips,
   browse rich multi-line rows, open a floating detail modal, stage installs
   (`i`) / removals (`x`) in a side panel, and run long actions inside
   floating modals.
4. **Charm v2 migration** — move the whole stack from the v1
   `github.com/charmbracelet/*` modules to v2 `charm.land/*` (Bubble Tea,
   Lipgloss, Bubbles) plus `bubblezone/v2` and `bubbletint/v2`, adopting real
   floating overlays (Lipgloss compositor/layers), live background-color
   detection, and first-class mouse support. Recorded in [ADR 0009](
   ../decisions/0009-charm-v1-to-v2-migration.md) and [ADR 0001](
   ../decisions/0001-bubbletea-v2-tui.md).
5. **Polish** — the brand mark traced from the flox SVG, the startup splash,
   the theme picker, and the four-pane review report ([ADR 0006](
   ../decisions/0006-four-pane-review-report.md)).

The Nerd-Font question was settled along the way: detection is unreliable, so
the TUI requires a Nerd Font with no ASCII fallback ([ADR 0002](
../decisions/0002-nerd-font-required.md)).

## Absorbing the audit engine (2026-06-18)

Quality scoring lived in a separate `review-skills` binary the TUI shelled
out to. To get a tight loop between the engine and a drill-down report, the
engine was moved into `flox-ai/internal/audit` and called in-process, the two
doctor concepts were unified, the CLI collapsed to a single `audit` command,
and the standalone package was deleted ([ADR 0003](
../decisions/0003-absorb-audit-engine-in-process.md),
[0004](../decisions/0004-unify-doctor.md),
[0005](../decisions/0005-single-audit-command.md)). This was built with the
brainstorm → plan → subagent-execute workflow described in
[workflow.md](workflow.md).

## Integrating main (2026-06-18)

By then `main` had independently added Agent Deck launch support. The branch
was brought current by squash-then-rebase ([ADR 0008](
../decisions/0008-squash-then-rebase.md)), and Agent Deck was wired into the
TUI's agent picker (display, description, and launch copy; claude kept as the
default).
