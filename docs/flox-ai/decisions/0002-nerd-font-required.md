# 0002. Require a Nerd Font; no ASCII fallback

Date: 2026-06-17

Status: Accepted

## Context

The TUI uses glyphs for fragment-type icons, status badges, the search
magnifier, the agent caret, and the flox brand mark. These come from a
Nerd Font (the Private Use Area). We considered detecting glyph support
at runtime — e.g. a cursor-position-report width probe — and degrading
to ASCII when a Nerd Font is absent.

The width probe cannot reliably distinguish a Nerd Font from a plain
font: many terminals report the same advance width for PUA code points
whether or not the glyph exists. Supporting two rendering paths also
doubles the surface we have to design and test, and the ASCII path is
always the worse experience.

## Decision

We will require a Nerd Font and document that requirement. There is
intentionally no ASCII fallback. We support a smaller surface and make
that experience good rather than degrade everywhere.

## Consequences

- `+` One rendering path to design, test, and keep beautiful.
- `+` Icons, badges, and the brand mark render as intended.
- `-` Users without a Nerd Font see tofu/placeholder glyphs; the README
  states the requirement up front.
