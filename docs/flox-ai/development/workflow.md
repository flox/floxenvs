# Workflow

## Branching and commits

- Work on a feature branch; do not commit to `main` directly.
- Conventional Commit subjects (`feat(flox-ai): …`, `fix(…)`,
  `refactor(…)`, `test(…)`, `chore(…)`, `docs(…)`, `build(…)`).
- Commit messages must not mention the AI assistant or add
  `Co-Authored-By` trailers (repo convention).
- The repo has no committed `.pre-commit-config.yaml` on this line, so
  the pre-commit wrapper aborts; commit with
  `PRE_COMMIT_ALLOW_NO_CONFIG=1 git commit …`.

## Larger features: brainstorm → plan → execute

Significant features are designed before they are built:

1. **Brainstorm** the design and write a spec to `.plans/`
   (`YYYY-MM-DD-<topic>-design.md`). Plans are not committed.
2. **Write an implementation plan** to `.plans/` — bite-sized, test-led
   tasks with real code.
3. **Execute** the plan task by task. For independent tasks, a fresh
   subagent implements each, followed by a spec-compliance review and a
   code-quality review before moving on.

The audit-engine merge was built this way; the spec and plan are in
`.plans/` and the decisions are recorded under
[decisions](../decisions/README.md).

## Integrating main

When a long-lived branch falls far behind `main`, prefer
squash-then-rebase to keep conflicts to a single point and a clean
history ([ADR 0008](../decisions/0008-squash-then-rebase.md)). Keep a
backup branch and assert tree-equality against it before rebasing.
Interactive rebase (`git rebase -i`) is unavailable in CI/agent shells;
squash non-interactively via `git reset --soft <merge-base>` and scoped
re-commits.

## Keeping docs current

These docs are part of the work, not an afterthought. When you change
behavior, update the matching tree (architecture/product/development)
and add a decision record for a significant choice. Finishing a task
includes leaving the docs true. See `AGENTS.md` at the repo root.
