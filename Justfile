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

# Website (Astro)
website-dev:
    cd .website && npm run dev

website-build:
    cd .website && npm run build

website-test:
    cd .website && npm run test

website-check:
    cd .website && npm run check
