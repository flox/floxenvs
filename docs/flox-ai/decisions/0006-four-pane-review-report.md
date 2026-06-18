# 0006. Render the review report as a sliding four-pane miller view

Date: 2026-06-18

Status: Accepted

## Context

The first review report was a two-pane modal: a list of audited
skills/agents on the left, a fixed detail panel on the right. Once the
in-process engine ([0003](0003-absorb-audit-engine-in-process.md))
could return per-tool findings and raw output, we wanted to let the
user drill from a skill, into its per-tool checks, into the findings
for one tool, into that tool's raw output — four levels.

Four full columns do not fit a floating modal on narrow terminals. The
chosen interaction is miller columns (like a file browser): drill right,
and the columns you came from collapse to thin slivers for breadcrumb
context, while the focused column and its child take the width.

## Decision

We will render the report as four panes — skills, checks, findings, raw
— with **two full panes visible at a time** (the focused pane and the
one to its right). Panes to the left collapse to ~8-cell slivers; the
window slides as focus moves right. `h`/`l` (and arrow keys) move focus
across panes; `j`/`k` move the cursor within the focused pane and reset
the cursors of deeper panes. Each pane's rows are mouse-clickable via
`bubblezone` markers (`rv:<pane>:<row>`). Below ~70 usable columns the
view falls back to a single full pane plus slivers. The selected
skill's dimension bars and overall score sit in a header above the
panes.

## Consequences

- `+` Progressive disclosure: overview to raw detail without leaving the
  modal.
- `+` Scales across terminal widths via the sliding window and the
  narrow fallback.
- `-` The modal re-centres as more panes/slivers appear when drilling;
  pinning the width is deferred polish.
- `-` The raw pane is keyboard-scrolled, not a clickable list, so it has
  no mouse hit target of its own.
