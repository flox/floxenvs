# Floxenvs local development recipes.
# Requires: just (installed via .flox/env/manifest.toml)
#
# Run `just` with no arguments to see this listing.

# Show available recipes with their descriptions and arguments
_default:
    @just --list --unsorted --list-heading $'Available recipes:\n  Run with: just <recipe> [args...]\n\n'

# Discover environments and output CI matrix JSON
discover-envs:
    bash scripts/discover-envs.sh

# Table of all environments with metadata
list-envs:
    bash scripts/discover-envs.sh --list

# Validate all manifests parse correctly
validate:
    bash scripts/discover-envs.sh --validate

# Website: start the Astro dev server with hot reload
website-dev:
    cd .website && npm ci && npm run dev

# Website: produce the static build in .website/dist
website-build:
    cd .website && npm ci && npm run build

# Website: run vitest unit tests for content libs
website-test:
    cd .website && npm ci && npm run test

# Website: run astro check (TypeScript + Astro diagnostics)
website-check:
    cd .website && npm ci && npm run check

# Website: build and push .website/dist to the gh-pages branch
website-push:
    cd .website && npm ci && npm run build
    cd .website && npx gh-pages \
        --dist dist \
        --branch gh-pages \
        --nojekyll \
        --message "deploy: $(git rev-parse --short HEAD) (from $(git rev-parse --abbrev-ref HEAD))"

# ── Audit pipeline (Plan B) ─────────────────────────────

# List every <kind>:<name>.
audit-list:
    bash scripts/list-items.sh

# Lint meta.yaml for a single item.
audit-meta-lint kind name:
    REPO_ROOT="$(pwd)" bash scripts/lint-meta.sh {{ kind }} {{ name }}

# Run the full audit pipeline for a single item.
audit-item kind name:
    REPO_ROOT="$(pwd)" bash scripts/run-audit.sh {{ kind }} {{ name }}

# Run all unit tests for the audit shell scripts.
audit-test:
    @set -e; \
    for t in scripts/test/*.test.sh; do \
      echo "── $$t"; bash "$$t"; \
    done
