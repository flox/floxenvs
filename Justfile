# Floxenvs local development recipes.
# Requires: just (added to devShell in flake.nix)

# Discover environments and output CI matrix JSON
discover-envs:
    bash scripts/discover-envs.sh

# Table of all environments with metadata
list-envs:
    bash scripts/discover-envs.sh --list

# Validate all manifests parse correctly
validate:
    bash scripts/discover-envs.sh --validate

# Site (Astro)
site-dev:
    cd site && npm run dev

site-build:
    cd site && npm run build

site-test:
    cd site && npm run test

site-check:
    cd site && npm run check
