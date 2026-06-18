# 0004. Unify fragment validation and tool availability in one doctor

Date: 2026-06-18

Status: Accepted

## Context

There were two distinct "doctor" concepts:

- flox-ai's `internal/doctor` validated fragment frontmatter (skills,
  agents, rules, plugins) — a static, structural check.
- review-skills' `doctor` probed the external quality tools: whether
  each is on PATH, its version, and a smoke test, plus the resolved
  default ensemble per artifact kind.

When the audit engine moved in-process ([0003](
0003-absorb-audit-engine-in-process.md)), keeping two separate doctor
packages would have left a confusing split and forced the TUI's
pre-review tool check to live somewhere ad hoc.

## Decision

We will merge the tool-availability probing into the existing
`flox-ai/internal/doctor` package as additional files, so one package
exposes both `Check` (fragment validation) and `Probe`/`Resolve` (tool
availability). The `flox-ai doctor` command renders them as two
sections: "Fragments" and "Audit tools". The dependency is one-way:
`doctor` imports `internal/audit/tools`; `audit` never imports
`doctor`.

## Consequences

- `+` One command answers both "are my fragments well-formed?" and "can
  I actually score them?".
- `+` The TUI's pre-review check and the install prompt read tool
  availability from `doctor.Probe` in-process, not by parsing CLI text.
- `-` One package now carries two responsibilities; they are kept in
  separate files (`doctor.go` vs `toolprobe.go`) to avoid sprawl.
