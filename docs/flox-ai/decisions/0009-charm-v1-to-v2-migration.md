# 0009. Migrate the TUI from Charm v1 to v2

Date: 2026-06-17

Status: Accepted

## Context

The TUI was first built and restyled on the v1 Charm stack
(`github.com/charmbracelet/*`): Bubble Tea, Lipgloss, and Bubbles. During that
work several capabilities we wanted were either awkward or missing on v1 —
real floating overlays, reliable terminal background-color detection for
light/dark theming, and clean mouse hit-testing.

Charm had published a v2 line under a new module path, `charm.land/*`, with
those capabilities as first-class features (`tea.View` with alt-screen and
mouse mode, `BackgroundColorMsg.IsDark()`, the Lipgloss compositor/layers) and
companion libraries `bubblezone/v2` and `bubbletint/v2`. v2 is a breaking
change: different module paths and several changed APIs (view construction,
key and mouse messages, adaptive color).

## Decision

We will migrate the entire TUI to the Charm v2 stack via the `charm.land/*`
module paths, and standardise on its features: the Lipgloss compositor for
floating modals, `BackgroundColorMsg`/`compat.AdaptiveColor` for light/dark,
`bubblezone/v2` for mouse zones, and `bubbletint/v2` for the theme picker. No
v1 code path is kept.

This supersedes the v1 restyle effort (same design goals, now on v2) and is
the concrete basis for [ADR 0001](0001-bubbletea-v2-tui.md).

## Consequences

- `+` Floating overlays, live light/dark adaptation, and mouse support are
  first-class instead of hand-rolled.
- `+` Access to the `bubbletint` theme registry and `bubblezone` hit-testing.
- `-` A one-time breaking migration: every import moves to `charm.land/*` and
  the changed v2 APIs had to be adopted across the model/update/view.
- `-` Contributors must use the `charm.land/*` paths, not the more familiar
  `github.com/charmbracelet/*`; v2 releases can still shift APIs, so upgrades
  need care (e.g. key-message construction in tests).
