# GitHub CI Agent Notes

Operational knowledge for working with this repo's GitHub Actions CI.
Read this before diagnosing or rerunning failed CI.

## Reruns

### `CI / Summary` failures

When the `CI / Summary` job is failing, rerun the **entire** CI workflow,
not just the failed job:

```bash
gh run rerun <ci-run-id>          # correct: whole workflow
gh run rerun <ci-run-id> --failed # wrong: Summary stays red
```

`Summary` aggregates the results of upstream jobs. Rerunning only the
failed `Summary` job (`--failed`) does not re-evaluate upstream results,
so it stays red. Always:

1. Fix or rerun whatever actually failed upstream (often an infra flake,
   see below).
2. Wait until every other job is green.
3. Then rerun the whole CI workflow so `Summary` re-evaluates.

## Infra flakes (not real build failures)

These look like build failures but are transient infrastructure problems.
Rerun the failed job; escalate only if it repeats.

### Wedged / unreachable Hetzner remote builder

Symptom in a `Build '<env>' (<system>)` job log:

```
cannot build on 'ssh-ng://nixbld@hetzner-aarch64-<host>': error: failed
to start SSH connection to 'hetzner-aarch64-<host>'
Failed to find a machine for remote build!
```

The remote builder is down or wedged. `aarch64-linux` and `aarch64-darwin`
builds run on Hetzner remote builders, so they hit this most.

- First response: `gh run rerun <run-id> --failed` for the CI Packages
  run, then rerun the whole CI workflow once green.
- If it keeps failing, the nix-daemon on the builder is wedged: ssh in as
  `rok@` (sudo), stop the service + socket, `pkill -9 nix-daemon`, then
  start the socket.

### Corrupt cache.nixos.org substitute

If a build fails pulling a substitute from `cache.nixos.org`, set
`NIX_CONFIG: fallback=true` so it falls back to building from source.

## Platform-specific build gotchas

### `x86_64-darwin` Rosetta timeout

`x86_64-darwin` builds run on `aarch64-darwin` runners under Rosetta.
Emulated install checks can hang past the 1800s silence timeout. Gate
`doInstallCheck` off for that platform.

### `weasyprint` darwin check

`weasyprint` pixel/font tests fail on darwin when built from source. Skip
`doCheck` on darwin. Only surfaces on PRs that edit the package (`main`
skips unchanged builds).

## Site job / concurrency

A global `concurrency: pages` group cancels the site job across many
concurrent PRs, which cancels CI Packages and makes `Summary` fail on
otherwise-green PRs. Fixed with a per-ref concurrency group (#4993). PRs
branched before that fix need `gh pr update-branch` to pick up the fixed
workflow.

## Lockfile / schema freshness

- Every env must have a committed `manifest.lock` (enforced by the
  `Invariants` workflow).
- Stable flox auto-bumps `compose.composer.schema-version` 1.10 → 1.11,
  which breaks the CI lockfile freshness check. Pin
  `schema-version = "1.11.0"` in the affected `manifest.toml`.
