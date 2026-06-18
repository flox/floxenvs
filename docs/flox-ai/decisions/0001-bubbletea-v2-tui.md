# 0001. Build the TUI on Bubble Tea v2 (charm.land)

Date: 2026-06-17

Status: Accepted

## Context

flox-ai needed an interactive terminal UI to browse the fragment
catalog, stage installs/uninstalls, switch agents, pick themes, and
launch an agent. The Go terminal-UI options were the Charm stack
(Bubble Tea) and a handful of lower-level libraries. Bubble Tea had a
v2 line published under the `charm.land/*` module path (distinct from
the older `github.com/charmbracelet/*` paths), with companion
libraries: Lipgloss v2 (styling), Bubbles v2 (components), plus
`bubblezone/v2` (mouse hit-testing) and `bubbletint/v2` (color themes).

v2 changed several APIs we depend on: `tea.View{Content, AltScreen,
MouseMode}`, `MouseClickMsg`, `BackgroundColorMsg.IsDark()`, and the
`compat`/`AdaptiveColor` light-dark handling.

## Decision

We will build the TUI on the Charm v2 stack via the `charm.land/*`
module paths: Bubble Tea v2, Lipgloss v2, Bubbles v2, with
`bubblezone/v2` for mouse zones and `bubbletint/v2` for the theme
picker. Mouse support uses `MouseModeCellMotion`; light/dark adaptation
uses `BackgroundColorMsg.IsDark()` and `compat.AdaptiveColor`.

## Consequences

- `+` Rich, composable model/update/view with first-class mouse,
  alt-screen, background-color detection, and a large theme registry.
- `+` `bubblezone` lets clickable regions be marked inline without
  manual coordinate math (markers are zero-width to Lipgloss).
- `-` The `charm.land/*` paths are separate from the more common
  `github.com/charmbracelet/*`; contributors must use the right import.
- `-` v2 is newer; some APIs shift between releases, so upgrades need
  care (e.g. key-message construction in tests).
