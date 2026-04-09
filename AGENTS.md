# Floxenvs — Agent Instructions

## Overview

This repo contains ready-to-use
[Flox](https://flox.dev) environments published to
[FloxHub](https://hub.flox.dev/flox). Each environment
follows a dual-layer pattern and is tested, containerized,
and published via GitHub Actions CI.

## Repository structure

```
floxenvs/
├── .flox/                  # Root flox env (build tools + custom packages)
│   ├── env/manifest.toml
│   └── pkgs/               # Custom nix packages
│       └── claude-code/
│           ├── default.nix
│           ├── hashes.json
│           ├── package-lock.json
│           ├── publish.json     # {"org": "flox-ai"}
│           └── upgrade.sh
├── .github/workflows/
│   ├── ci.yml               # Coordinator (wait, summary, auto-merge, containerize)
│   ├── environment.yml       # Reusable workflow (discover, test, push)
│   ├── ci_<name>.yml         # Per-environment trigger
│   ├── ci_pkgs.yml           # Build/publish custom packages
│   ├── upgrade_envs.yml      # Weekly environment lockfile upgrades
│   └── upgrade_pkgs.yml      # 6-hourly package version upgrades
├── scripts/
│   └── discover-envs.sh      # Shared discovery script
├── flake.nix                 # Nix flake with run-test script
├── <name>/                   # Minimal environment
│   ├── .flox/env/manifest.toml
│   ├── .flox/env/manifest.lock
│   ├── test.sh
│   ├── README.md
│   └── push.json             # Optional: {"org": "flox-ai"}
├── <name>-demo/              # Demo environment
│   ├── .flox/env/manifest.toml
│   ├── .flox/env/manifest.lock
│   ├── test.sh
│   └── README.md
└── README.md
```

## Dual-layer pattern

Every environment has two layers:

### Minimal (`<name>/`)

Designed for `[include]` composition. Users include
this in their own manifest:

```toml
[include]
environments = ["flox/<name>"]
```

Rules for minimal environments:

- No gum, no coreutils, no spinner UI
- No sample project files
- No `[options]` systems list (ADR-004)
- Use `pkg-group = "<name>"` for the main package
- Use `schema-version = "1.10.0"` or newer
- Silent hooks (no echo/print on activate)
- Store data in `$FLOX_ENV_CACHE/<name>`
- Service commands must re-derive the data path
  (don't rely on hook exports)
- Port numbers prefixed with `1` (ADR-003):
  PostgreSQL 15432, Redis 16379, MySQL 13306, etc.
- Include a comment block showing `[include]` usage
- `test.sh` verifies commands exist and services start
- `README.md` documents usage, variables, and links
  to demo

### Demo (`<name>-demo/`)

Interactive variant with gum UI and sample projects:

```toml
[include]
environments = [
  { dir = "../<name>" }
]

[install]
gum.pkg-path = "gum"
gum.pkg-group = "demo-tools"
```

Rules for demo environments:

- Always includes the minimal env via `[include]`
- Adds `gum` in `demo-tools` pkg-group
- Hook shows a styled banner (skip when
  `FLOX_ENVS_TESTING=1`)
- Contains sample project files (requirements.txt,
  package.json, Gemfile, etc.)
- `test.sh` verifies the sample project works
- `README.md` includes setup walkthrough

## Writing a new environment

### Step 1: Create minimal environment

```bash
mkdir -p <name>/.flox/env
```

Write `<name>/.flox/env/manifest.toml`:

```toml
schema-version = "1.10.0"

# Minimal <Name> environment for use with [include].
#
# Include it in your own manifest:
#
#   [include]
#   environments = ["flox/<name>"]

[install]
<pkg>.pkg-path = "<pkg>"
<pkg>.pkg-group = "<name>"

[vars]
# Environment variables with sensible defaults

[hook]
on-activate = '''
# Setup logic: create cache dirs, detect changes, etc.
'''

[services]
# Optional: service definitions
```

Generate the lockfile:

```bash
cd <name> && flox edit -f .flox/env/manifest.toml
```

Write `<name>/test.sh`:

```bash
#!/usr/bin/env bash
set -eo pipefail

if ! command -v <cmd> >/dev/null 2>&1; then
  echo "Error: '<cmd>' command not found."
  exit 1
fi
echo ">>> <cmd> version: $(<cmd> --version)"
echo ">>> <name> environment is working"
```

Write `<name>/README.md` documenting:

- What it provides
- `[include]` usage (dir and FloxHub)
- Configuration variables
- How services work (if applicable)
- Link to `<name>-demo`

### Step 2: Create demo environment

```bash
mkdir -p <name>-demo && cd <name>-demo && flox init
```

Write the manifest with `[include]` and gum.
Apply: `flox edit -f .flox/env/manifest.toml`

Add sample project files, test.sh, README.md.

### Step 3: Add CI workflow

Create `.github/workflows/ci_<name>.yml`:

```yaml
name: "CI: <name>"

on:
  push:
    branches: ["main"]
    paths:
      - "<name>/**"
      - "<name>-demo/**"
      - "flake.nix"
      - "flake.lock"
      - "scripts/**"
      - ".github/workflows/environment.yml"
      - ".github/workflows/ci_<name>.yml"
  pull_request:
    paths:
      - "<name>/**"
      - "<name>-demo/**"
      - "flake.nix"
      - "flake.lock"
      - "scripts/**"
      - ".github/workflows/environment.yml"
      - ".github/workflows/ci_<name>.yml"
  workflow_dispatch:

permissions:
  contents: "read"
  packages: "write"
  attestations: "write"
  id-token: "write"

jobs:
  run:
    uses: "./.github/workflows/environment.yml"
    with:
      environment: "<name>"
    secrets: inherit
```

### Step 4: Update README.md

Add the environment to the root README.md table with
floxhub, docs, and docker links for both minimal and
demo.

## CI architecture

### Three layers

```
ci_<name>.yml          Thin trigger (path filters)
    │
    └──▶ environment.yml    Reusable workflow
              │
              ├── discover   Read manifest.lock for
              │              systems, services, demo
              ├── test       SSH to remote builder,
              │              nix run .#run-test
              ├── test-demo  Same for demo
              ├── push       Sync to FloxHub
              └── push-demo  Rewrite include → remote,
                             sync to FloxHub

ci.yml                 Coordinator
    │
    ├── wait           Poll until all CI: * complete
    ├── summary        Pass/fail gate for branch
    │                  protection
    ├── auto-merge     Approve + merge floxbot PRs
    ├── containerize   Build Docker images
    │                  (max-parallel: 4)
    └── report-failure Slack notification
```

### Test execution

Tests run on remote builders via SSH over Tailscale.
On Linux, tests are isolated in user + network + PID
namespaces using `pasta` (from passt project) for
network connectivity. See `flake.nix` for details.

### FloxHub target org

By default, environments push to the `flox` org on
FloxHub. To push to a different org, create a
`push.json` in the environment directory:

```json
{"org": "flox-ai"}
```

Similarly, custom packages use `publish.json`:

```json
{"org": "flox-ai"}
```

### Lockfile freshness check

The discover job regenerates lockfiles and fails if
they differ from what's committed. Always regenerate
after manifest changes:

```bash
cd <name> && flox edit -f .flox/env/manifest.toml
cd <name>-demo && flox include upgrade
```

## Custom packages

Custom nix packages live in `.flox/pkgs/<name>/`.
Each package has:

- `default.nix` — nix derivation
- `hashes.json` — version + hashes
- `upgrade.sh` — script to check for new versions
- `publish.json` — target org for publishing

`ci_pkgs.yml` builds changed packages on PR and
publishes to FloxHub on main. `upgrade_pkgs.yml`
runs `upgrade.sh` every 6 hours and creates a PR
if a new version is found.

## ADR summary

| ADR | Decision |
| --- | -------- |
| 001 | Use `-demo` suffix for interactive variants |
| 002 | Store data in `$FLOX_ENV_CACHE/<service>` |
| 003 | Prefix standard ports with `1` (e.g. 15432) |
| 004 | Omit `[options]` systems list |
| 006 | One Python env per package manager |
| 007 | `helpf`/gum only in demo variants |

## Git workflow

- One worktree per feature: `.worktrees/<name>`
- Branch from latest `origin/main`
- One PR per environment or small batch
- Verify CI green before merging
- Commit lockfile changes together with manifest
- Don't push without reviewing changes first
