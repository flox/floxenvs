# Testing

flox-ai has Go unit tests and a bats end-to-end suite.

## Unit tests

```sh
nix develop --command flox activate -- bash -c '
  cd .flox/pkgs/flox-ai && go test ./...'
```

Notable coverage:

- `internal/audit/...` — the scoring engine, tool registry, findings,
  and report (moved with the engine; includes the `IncludeRaw` test).
- `internal/doctor` — fragment validation and the tool probe.
- `internal/tui` — the four-pane review navigation, the agent picker and
  default selection, and the rest of the model. UI tests inject a fake
  `Auditor` so they do not run external tools.
- `main_audit_test.go` — the `audit` command, including interspersed
  flag parsing (flags after the path).

## End-to-end (bats)

The e2e suite lives in `.flox/pkgs/flox-ai/e2e/*.bats` and runs the real
binary. Run it through the flake apps:

```sh
# whole suite
nix run '.#run-test-flox-ai-with-nix'
# one file
nix run '.#run-test-flox-ai-with-nix' -- .flox/pkgs/flox-ai/e2e/audit.bats
```

Coverage includes setup-hook/profile, fragment management
(rules/skills/agents/plugins), `doctor` (including the audit-tools
section), `launch` (claude and agent-deck), and `audit`.

## The dry-run mode

`audit` and `report` execute external tools. To keep e2e hermetic, set
`REVIEW_SKILLS_DRY_RUN=1`: the engine emits fixed stub scores and raw
output without running any tool. `e2e/audit.bats` uses this so it needs
no tools on PATH.

## Note on the bats e2e build source

The flake builds flox-ai from the git tree, so a new test file must be
`git add`-ed before the e2e run will see it (see
[build.md](build.md)).
