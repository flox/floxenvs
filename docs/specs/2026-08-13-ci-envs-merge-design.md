# Merge per-environment CI workflows into one `ci_envs.yml`

Status: approved (step 1 of 2; step 2 — chunking envs like
`ci_pkgs.yml` — is a separate follow-up spec)

## Problem

49 `ci_<env>.yml` files exist, one per environment. Each is a thin
caller: hardcoded path triggers (`<env>/**`, `<env>-demo/**`, shared
files) plus a call of the reusable `environment.yml` with the env
name. Costs: file sprawl, per-env drift in triggers, a new env
requires a new workflow file, and `ci.yml`'s Wait-Envs job must poll
N separate workflow runs by the `CI: *` name prefix.

## Decision

One workflow, `ci_envs.yml` (display name `CI Environments`),
replaces all 49 callers. The reusable `environment.yml` stays
untouched and is called through a matrix.

### Triggers

- `push` to `main` and `pull_request` — broad (no `paths` filter);
  a cheap discover job selects the envs to run. Zero selected envs
  means no matrix jobs spawn.
- `workflow_dispatch` with optional `environment` input — empty runs
  discovery over all envs; a name runs exactly that env.

### Discover job

Diff base rules (same as `ci_pkgs.yml`): PR base sha for PRs; the
push event's `before` sha (fallback `HEAD~1`) for pushes.

Selection rules, in order:

1. Dispatch with `environment=<name>` — exactly that env.
2. Any shared file changed (`flake.nix`, `flake.lock`, `scripts/**`,
   `.github/workflows/environment.yml`,
   `.github/workflows/ci_envs.yml`) — all envs.
3. Otherwise — every env whose `<env>/**` or `<env>-demo/**`
   contains a changed file.

Env enumeration is directory-driven: top-level dirs that contain
`.flox/env/manifest.toml`, demo dirs paired by the `-demo` suffix.
No hardcoded env list anywhere.

Output: JSON array of env names.

### Run job

```yaml
run:
  name: "${{ matrix.environment }}"
  needs: ["discover"]
  if: needs.discover.outputs.environments != '[]'
  strategy:
    fail-fast: false
    matrix:
      environment: ${{ fromJSON(needs.discover.outputs.environments) }}
  uses: "./.github/workflows/environment.yml"
  with:
    environment: "${{ matrix.environment }}"
  secrets: inherit
```

`fail-fast: false` is load-bearing: one env failing must not cancel
the others (today they are independent workflows).

Permissions block copied verbatim from the current callers
(`contents: read`, `packages: write`, `attestations: write`,
`id-token: write`).

### `ci.yml` Wait-Envs integration

Today it polls `listWorkflowRunsForRepo` for the head sha and
filters run names by the `CI: ` prefix. Change the filter to the
exact name `CI Environments` (at most one run per sha):

- No run found after the grace window — nothing to wait for (same
  as today's empty case).
- Run completed with `success` or `skipped` — pass.
- Run completed otherwise — fetch the run's jobs; failed matrix job
  names (which carry the env name, e.g. `kafka / ...`) feed the
  existing `failed_workflows` / `successful_envs` outputs so the
  Summary message keeps naming the broken envs.

`scripts/wait-should-poll.sh` (paths-based short-circuit) stays
as-is.

### Deletions

All 49 `.github/workflows/ci_<env>.yml` files.

## GitHub limits (verified against docs)

| Limit | Value | Our usage |
| ----------------------------- | ----- | ------------------ |
| Unique reusable workflow files per call tree | 20 | 1 |
| Call nesting depth | 4 | 2 |
| Jobs per matrix | 256 | 49 |
| Check runs per suite | ~1000 | ~300-450 jobs/run |

Matrix entries calling the same reusable file count once against the
20-file limit. Inner `environment.yml` matrices (~4 systems, demos)
count against their own 256 cap, not the caller's.

## Behavior changes (accepted)

- Actions UI: one `CI Environments` run with nested per-env groups
  instead of N separate runs. Job names become
  `<env> / <inner job name>`.
- The `CI: <env>` workflow names disappear. Verified consumers:
  only `ci.yml` Wait-Envs (adapted above); branch protection
  requires only `Summary`; no badges reference per-env workflows.
- Every PR gains one ~30s discover job (broad trigger). Accepted as
  the price of a self-maintaining trigger.

## Testing

1. PR touching one env dir — discover selects exactly that env;
   matrix spawns one nested call.
2. PR touching `flake.lock` — all envs selected.
3. PR touching only `.flox/pkgs/**` — discover selects nothing; no
   matrix jobs; Wait-Envs short-circuits as today.
4. `workflow_dispatch` with `environment=kafka` — one env.
5. Failure isolation — force one env red, confirm others complete
   and Summary names the failed env.

## Out of scope (step 2)

Grouping/chunking several envs into one job the way `ci_pkgs.yml`
chunks packages. The discover job built here is the insertion point
for that later.
