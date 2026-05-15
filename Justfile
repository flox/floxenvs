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
    cd .website && npm run dev

# Website: produce the static build in .website/dist
website-build:
    cd .website && npm run build

# Website: run vitest unit tests for content libs
website-test:
    cd .website && npm run test

# Website: run astro check (TypeScript + Astro diagnostics)
website-check:
    cd .website && npm run check

# Website: build and push .website/dist to the gh-pages branch
website-push:
    cd .website && npm run build
    cd .website && npx gh-pages \
        --dist dist \
        --branch gh-pages \
        --nojekyll \
        --message "deploy: $(git rev-parse --short HEAD) (from $(git rev-parse --abbrev-ref HEAD))"
