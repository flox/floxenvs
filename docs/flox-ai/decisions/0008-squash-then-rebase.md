# 0008. Integrate main by squash-then-rebase

Date: 2026-06-18

Status: Accepted

## Context

The `feature/flox-ai-tui` branch had developed 62 commits while `main`
moved 352 commits ahead, including a parallel flox-ai line that added
agent-deck launch support. The branch needed main's work (notably
agent-deck) and to be current before merge.

The true conflict surface was small — `go.mod`, `go.sum`,
`default.nix`, `main.go`, and two demo-env lockfiles — but spread across
62 commits a straight rebase would replay those conflicts many times,
and intermediate commits would not build. The environment also blocks
interactive rebase (`git rebase -i`).

## Decision

We will squash the branch's 62 commits into a handful of logical,
file-partitioned commits, then rebase those onto `origin/main`. The
squash is done non-interactively: `git reset --soft <merge-base>`,
re-commit in scoped groups, and assert the resulting tree is identical
to a pre-rebase backup branch before rebasing. Build-file conflicts are
resolved once (`go.mod`/`go.sum` reconciled with `go mod tidy`;
`vendorHash` recomputed via the fake-hash dance). A backup branch,
`backup/flox-ai-tui-pre-rebase`, is kept.

## Consequences

- `+` Conflicts resolved at one or two commits instead of dozens; every
  resulting commit builds.
- `+` A clean, readable history on top of main.
- `-` Granular per-step history is collapsed; the narrative lives in
  these docs and the PRD instead.
- `-` Requires a tree-equality check against the backup to be safe,
  because non-interactive squashing is easy to get subtly wrong (a
  missed file).
