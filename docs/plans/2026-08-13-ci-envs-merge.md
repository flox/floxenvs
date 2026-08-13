# Merge per-env CI workflows into ci_envs.yml — Implementation Plan

> **Note:** `scripts/discover-envs.sh` below was renamed to
> `scripts/select-envs.sh` post-review — it collided with a
> pre-existing manifest.lock parser of the same name.

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 49 `ci_<env>.yml` caller workflows with one
`ci_envs.yml` that discovers changed environments and matrix-calls
the untouched reusable `environment.yml`.

**Architecture:** New workflow = broad trigger + discover job
(changed-path diff, dispatch override, shared-path → all envs) +
matrix `uses:` job. `ci.yml` Wait-Envs switches from polling N
`CI: *` runs to polling the single `CI Environments` run and reads
per-env results from its job names. Spec:
`docs/specs/2026-08-13-ci-envs-merge-design.md`.

**Tech Stack:** GitHub Actions (reusable workflows, matrix over
`uses:`), bash + jq, actions/github-script JS.

## Global Constraints

- `environment.yml` must NOT be modified.
- `fail-fast: false` on the matrix — one env failing must not cancel
  others.
- Permissions block copied verbatim from current callers:
  `contents: read`, `packages: write`, `attestations: write`,
  `id-token: write`.
- Env enumeration is directory-driven (dirs containing
  `.flox/env/manifest.toml`, demo dirs paired by `-demo` suffix) —
  no hardcoded env list.
- Shared files that select ALL envs: `flake.nix`, `flake.lock`,
  `scripts/**`, `.github/workflows/environment.yml`,
  `.github/workflows/ci_envs.yml`.
- Commit messages: never mention Claude.
- Workflow display name: `CI Environments`.

---

### Task 1: Discover script (testable outside CI)

**Files:**
- Create: `scripts/discover-envs.sh`
- Test: run locally against synthetic diffs (steps below)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `scripts/discover-envs.sh` — stdin: newline-separated
  changed file paths; arg 1 (optional): single-env override; stdout:
  compact JSON array of env names. Task 2's workflow calls it as
  `scripts/discover-envs.sh [env] < changed-files.txt`.

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# discover-envs.sh — select environments to run CI for.
#
#   scripts/discover-envs.sh [single-env] < changed-file-paths
#
# stdin: newline-separated changed file paths (ignored when
#        single-env is given).
# arg1:  optional single environment name — output exactly that env
#        (workflow_dispatch override). "all" or "" means: no
#        override.
# stdout: compact JSON array of environment names.
#
# Selection rules:
#   1. arg1 set (not "" / "all")  -> exactly that env
#   2. any SHARED path changed    -> all envs
#   3. otherwise                  -> envs whose <env>/** or
#                                    <env>-demo/** changed
#
# Environments are discovered from the tree: every top-level
# directory containing .flox/env/manifest.toml whose name does not
# end in -demo. Demo dirs are owned by their base env.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

single="${1:-}"

# ── Enumerate environments from the tree ──
envs=()
for d in */; do
  name="${d%/}"
  case "$name" in *-demo) continue ;; esac
  [ -f "$name/.flox/env/manifest.toml" ] && envs+=("$name")
done

if [ -n "$single" ] && [ "$single" != "all" ]; then
  for e in "${envs[@]}"; do
    if [ "$e" = "$single" ]; then
      jq -cn --arg e "$single" '[$e]'
      exit 0
    fi
  done
  echo "ERROR: unknown environment '$single'" >&2
  exit 1
fi

changed="$(cat)"

# ── Shared paths: any hit selects every env ──
if echo "$changed" | grep -qE \
  '^(flake\.nix|flake\.lock|scripts/|\.github/workflows/environment\.yml|\.github/workflows/ci_envs\.yml)'; then
  printf '%s\n' "${envs[@]}" | jq -Rc . | jq -sc .
  exit 0
fi

# ── Per-env selection ──
selected=()
for e in "${envs[@]}"; do
  if echo "$changed" | grep -qE "^$e(-demo)?/"; then
    selected+=("$e")
  fi
done

if [ ${#selected[@]} -eq 0 ]; then
  echo "[]"
else
  printf '%s\n' "${selected[@]}" | jq -Rc . | jq -sc .
fi
```

- [ ] **Step 2: Make executable, syntax check**

Run: `chmod +x scripts/discover-envs.sh && bash -n scripts/discover-envs.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Test all selection rules**

Run each; compare output exactly:

```bash
# single env change
echo "kafka/.flox/env/manifest.toml" | scripts/discover-envs.sh
# -> ["kafka"]

# demo dir maps to base env
echo "kafka-demo/compose.yaml" | scripts/discover-envs.sh
# -> ["kafka"]

# shared file selects all (count must equal env dir count)
echo "flake.lock" | scripts/discover-envs.sh | jq length
# -> 49 (or current env count: ls -d */ | grep -cv -- '-demo/')

# unrelated path selects nothing
echo ".flox/pkgs/codex/hashes.json" | scripts/discover-envs.sh
# -> []

# dispatch override ignores stdin
echo "" | scripts/discover-envs.sh kafka
# -> ["kafka"]

# unknown env errors
echo "" | scripts/discover-envs.sh nosuchenv; echo "exit=$?"
# -> ERROR on stderr, exit=1

# multi-env change
printf 'kafka/x\nredis/y\n' | scripts/discover-envs.sh
# -> ["kafka","redis"]
```

Expected: outputs as annotated.

- [ ] **Step 4: Commit**

```bash
git add scripts/discover-envs.sh
git commit -m "feat(ci): add discover-envs.sh env selection script"
```

### Task 2: `ci_envs.yml` workflow

**Files:**
- Create: `.github/workflows/ci_envs.yml`

**Interfaces:**
- Consumes: `scripts/discover-envs.sh [env] < changed-files`
  (Task 1) — stdout JSON array.
- Produces: workflow named `CI Environments`, matrix job display
  names `<env> / <inner job>`. Task 3's Wait-Envs polling relies on
  the exact workflow name `CI Environments` and on the
  `<env> / ...` job-name prefix.

- [ ] **Step 1: Write the workflow**

```yaml
name: "CI Environments"

# One workflow replaces the 49 per-env ci_<env>.yml callers.
# Broad trigger + discover: a cheap job diffs changed paths and
# selects the envs to run (scripts/discover-envs.sh); zero selected
# envs spawns no matrix jobs. The reusable environment.yml is
# unchanged and called once per selected env.

on:
  push:
    branches: ["main"]
  pull_request:
  workflow_dispatch:
    inputs:
      environment:
        description: >
          Single environment to run. Leave empty (or "all") to run
          discovery over all environments.
        required: false
        default: ""
        type: string

permissions:
  contents: "read"
  packages: "write"
  attestations: "write"
  id-token: "write"

env:
  FLOX_DISABLE_METRICS: "true"

jobs:

  discover:
    name: "Discover changed environments"
    runs-on: "ubuntu-latest"
    timeout-minutes: 5
    outputs:
      environments: "${{ steps.discover.outputs.environments }}"
    steps:
      - name: "Checkout"
        uses: "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1" # v7.0.1
        with:
          fetch-depth: 0
      - name: "Select environments"
        id: "discover"
        env:
          SINGLE_ENV: "${{ inputs.environment }}"
          EVENT: "${{ github.event_name }}"
          BASE_SHA: "${{ github.event.pull_request.base.sha }}"
          BEFORE_SHA: "${{ github.event.before }}"
        run: |
          set -euo pipefail

          if [ "$EVENT" = "workflow_dispatch" ] \
             && { [ -z "$SINGLE_ENV" ] || [ "$SINGLE_ENV" = "all" ]; }; then
            # Dispatch without a target: run everything.
            envs="$(echo "flake.lock" | scripts/discover-envs.sh)"
          elif [ "$EVENT" = "workflow_dispatch" ]; then
            envs="$(echo "" | scripts/discover-envs.sh "$SINGLE_ENV")"
          else
            if [ "$EVENT" = "pull_request" ]; then
              DIFF_BASE="$BASE_SHA"
            else
              # Diff the whole push (coalesced merge waves); fall
              # back to HEAD~1 on force-push / new branch.
              DIFF_BASE="$BEFORE_SHA"
              if [ -z "$DIFF_BASE" ] \
                 || ! git cat-file -e "$DIFF_BASE" 2>/dev/null; then
                DIFF_BASE="HEAD~1"
              fi
            fi
            envs="$(git diff --name-only "$DIFF_BASE" HEAD \
              | scripts/discover-envs.sh)"
          fi

          echo "environments=$envs" >> "$GITHUB_OUTPUT"
          echo "Selected: $envs"

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

- [ ] **Step 2: Validate YAML**

Run: `ruby -ryaml -e 'YAML.safe_load(File.read(".github/workflows/ci_envs.yml"), aliases: true); puts "OK"'`
Expected: `OK`.

- [ ] **Step 3: Simulate the discover step body locally**

```bash
cd "$(git rev-parse --show-toplevel)"
# pull_request path
git diff --name-only origin/main HEAD | scripts/discover-envs.sh
# -> [] (branch touches no env dirs yet)
# dispatch-all path
echo "flake.lock" | scripts/discover-envs.sh | jq length
# -> current env count
```

Expected: as annotated.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci_envs.yml
git commit -m "feat(ci): single CI Environments workflow with env discovery"
```

### Task 3: Adapt `ci.yml` Wait-Envs to the single workflow

**Files:**
- Modify: `.github/workflows/ci.yml` (the
  `Wait for all CI: * workflows` github-script step, ~lines 98-230)

**Interfaces:**
- Consumes: workflow name `CI Environments` and `<env> / ...` job
  names (Task 2).
- Produces: unchanged step outputs consumed by the existing Summary
  job: `any_failed` (string bool), `failed_workflows`
  (comma-separated env names), `total_workflows` (count),
  `successful_envs` (JSON array of env names), `pr_number`,
  `pr_author`.

- [ ] **Step 1: Replace the run filter + result extraction**

In the github-script block, replace the `CI: ` prefix filter:

```javascript
// OLD
const ciRuns = runs.data.workflow_runs.filter(
  r => r.name.startsWith('CI: ')
);
```

```javascript
// NEW — one merged workflow per sha
const ciRuns = runs.data.workflow_runs.filter(
  r => r.name === 'CI Environments'
);
```

Where the old code derived per-workflow results (the completion
branch that sets outputs from `ciRuns` names — success list from
runs with `conclusion === 'success'`, failed list from the rest),
derive per-ENV results from the single run's jobs instead:

```javascript
// The merged run's matrix jobs are named "<env> / <inner job>".
// An env failed if ANY of its jobs failed; it succeeded if all of
// its jobs completed without failure. Discover/site-level jobs
// (no " / " in the name) are ignored for env attribution.
const run = ciRuns[0];
const jobs = await github.paginate(
  github.rest.actions.listJobsForWorkflowRun,
  {
    owner: context.repo.owner,
    repo: context.repo.repo,
    run_id: run.id,
    filter: 'latest',
    per_page: 100,
  }
);
const envResults = new Map();
for (const job of jobs) {
  const idx = job.name.indexOf(' / ');
  if (idx === -1) continue;
  const env = job.name.slice(0, idx);
  const bad = job.conclusion !== null
    && job.conclusion !== 'success'
    && job.conclusion !== 'skipped';
  envResults.set(env, (envResults.get(env) || false) || bad);
}
const failedEnvs = [...envResults.entries()]
  .filter(([, bad]) => bad).map(([env]) => env).sort();
const okEnvs = [...envResults.entries()]
  .filter(([, bad]) => !bad).map(([env]) => env).sort();

core.setOutput('any_failed', String(failedEnvs.length > 0));
core.setOutput('failed_workflows', failedEnvs.join(', '));
core.setOutput('total_workflows', String(envResults.size));
core.setOutput('successful_envs', JSON.stringify(okEnvs));
core.setOutput('pr_number', prNumber.toString());
core.setOutput('pr_author', prAuthor);
```

Keep unchanged: the merge_group early-pass, the 30s registration
grace, the polling loop shape (pending check now:
`ciRuns[0].status !== 'completed'`), the no-runs-found fallback,
and the two-hour timeout. Read the whole step before editing —
adapt variable names to what is actually there; the goal is filter
+ attribution changes only.

- [ ] **Step 2: Validate YAML + JS syntax**

Run:

```bash
ruby -ryaml -e 'YAML.safe_load(File.read(".github/workflows/ci.yml"), aliases: true); puts "OK"'
# Extract the script block and syntax-check it:
python3 - <<'EOF'
import re, subprocess, sys
src = open('.github/workflows/ci.yml').read()
# crude but effective: find the github-script "script: |" block
m = re.search(r'script: \|\n((?:            .*\n|\n)+)', src)
open('/tmp/wait.js', 'w').write(re.sub(r'^            ', '', m.group(1), flags=re.M))
sys.exit(subprocess.call(['node', '--check', '/tmp/wait.js']))
EOF
```

Expected: `OK`, then node exits 0.

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "feat(ci): wait on single CI Environments run in Summary gate"
```

### Task 4: Delete the 49 per-env callers

**Files:**
- Delete: `.github/workflows/ci_1password.yml` … `ci_worktrunk.yml`
  (every `ci_<env>.yml` EXCEPT `ci_pkgs.yml` and `ci_envs.yml`)

**Interfaces:**
- Consumes: Task 2's workflow must exist first (same branch).
- Produces: nothing new.

- [ ] **Step 1: Delete exactly the env callers**

```bash
cd "$(git rev-parse --show-toplevel)"
for f in .github/workflows/ci_*.yml; do
  case "$f" in
    */ci_pkgs.yml|*/ci_envs.yml) continue ;;
  esac
  git rm -q "$f"
done
git status --short | head
```

Expected: 49 `D` lines, `ci_pkgs.yml` and `ci_envs.yml` untouched.

- [ ] **Step 2: Verify nothing else references the deleted files**

Run: `grep -rn 'ci_1password\|ci_kafka\|"CI: ' .github/ scripts/ Justfile 2>/dev/null | grep -v ci_envs`
Expected: no hits (any hit = a consumer the spec missed; stop and
surface it).

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(ci): remove per-env caller workflows replaced by ci_envs.yml"
```

### Task 5: Branch validation on real CI

**Files:** none (operational).

**Interfaces:**
- Consumes: everything pushed on the feature branch.

- [ ] **Step 1: Push branch, open PR**

```bash
git push -u origin feature/ci-envs-merge
gh pr create \
  --title "feat(ci): merge per-env CI workflows into ci_envs.yml" \
  --body "Implements docs/specs/2026-08-13-ci-envs-merge-design.md: one CI Environments workflow (broad trigger + discover + matrix over reusable environment.yml) replaces 49 ci_<env>.yml callers; ci.yml Wait-Envs polls the single run and attributes per-env results from job names."
```

Expected: PR URL. The PR itself only touches `.github` + `scripts`
+ `docs`, so discover selects `[]` via the changed-paths rule —
wait: `scripts/**` is a SHARED path, so this PR selects ALL envs.
That is the intended full-fleet validation run.

- [ ] **Step 2: Watch the PR's CI Environments run**

Run: `gh run list --workflow ci_envs.yml --branch feature/ci-envs-merge --limit 1`
then watch the run id. Expected: discover selects all envs; matrix
spawns one nested call per env; failures (if any) are env-content
issues, not workflow-shape issues — compare against the same env's
result on main before diagnosing.

- [ ] **Step 3: Dispatch single-env run**

```bash
gh workflow run ci_envs.yml --ref feature/ci-envs-merge -f environment=dotenv
```

Expected: run with exactly one matrix entry (`dotenv`).

- [ ] **Step 4: Verify Summary gate on the PR**

The PR's `CI / Summary` check must go green and its Wait-Envs log
must show `CI Environments` polling (not `CI: *`). Expected: green.

## Self-Review

- Spec coverage: triggers/discover (Tasks 1-2), Wait-Envs (Task 3),
  deletions (Task 4), testing section (Tasks 1 step 3, 5). Limits
  table needs no code. Covered.
- Placeholders: none; all code inline.
- Type consistency: `environments` output name and
  `scripts/discover-envs.sh` contract match across Tasks 1-2;
  `CI Environments` name matches across Tasks 2-3.
