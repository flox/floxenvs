#!/usr/bin/env bash
# coexist-check.sh — prove that ALL skill packages + every agent runtime +
# every audit tool can be installed into ONE Flox environment.
#
# This tests FLOX, not Nix: it creates a throwaway Flox environment, changes
# into it, and runs `flox install` for every package one at a time. `flox
# install` rejects a package that conflicts with one already in the
# environment (the original bug: four python skills each shipped bin/python3
# and clashed on $FLOX_ENV/bin/python3). If every install succeeds, the whole
# set coexists in a single Flox environment. The throwaway environment is
# deleted at the end, pass or fail.
#
# NOTE: `flox install` resolves packages from the CATALOG (pkg-path), so this
# validates the PUBLISHED packages. After the bin-removal refactor is
# republished, the formerly-colliding skills install cleanly together.
#
# Usage (plain shell, NOT inside `flox activate`):
#   bash scripts/coexist-check.sh
# Exit 0 + "coexist OK" if every package installs; non-zero (listing the
# packages that failed to install) otherwise.

set -uo pipefail

# ── Locate the repo root (to read the skill package list) ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ ! -d "$REPO_ROOT/.flox/pkgs" ]; then
  echo "ERROR: cannot find .flox/pkgs under $REPO_ROOT — run from the repo." >&2
  exit 2
fi

if ! command -v flox >/dev/null 2>&1; then
  echo "ERROR: flox not found on PATH." >&2
  exit 2
fi

# ── Compute the target package list (catalog pkg-paths) ──
# 63 skill packages: every package whose default.nix uses flox_agent_layout.
mapfile -t SKILLS < <(
  grep -rl 'flox_agent_layout' "$REPO_ROOT"/.flox/pkgs/*/default.nix \
    | xargs -n1 dirname | xargs -n1 basename | sort -u
)
# The 4 agent runtimes + the 6 audit tools.
TOOLS=(
  claude-code codex opencode pi
  flox-ai skill-tools skill-validator skillcheck skillspector claudelint
)
PACKAGES=("${SKILLS[@]}" "${TOOLS[@]}")
echo "Target: ${#SKILLS[@]} skills + ${#TOOLS[@]} agents/audit tools = ${#PACKAGES[@]} packages"

# ── Create a throwaway Flox environment and change into it ──
ENV_DIR="$(mktemp -d)"
cleanup() {
  # Remove the throwaway environment (and its directory), pass or fail.
  flox delete -d "$ENV_DIR" -f >/dev/null 2>&1 || true
  rm -rf "$ENV_DIR"
}
trap cleanup EXIT

cd "$ENV_DIR"
echo "Creating throwaway environment in $ENV_DIR ..."
if ! flox init >/dev/null 2>&1; then
  echo "ERROR: flox init failed in $ENV_DIR" >&2
  exit 2
fi

# ── Install every package, one at a time, into the single environment ──
# `flox install` fails if a package conflicts with one already installed, so a
# per-package loop pinpoints exactly which package the environment rejects.
FAILED=()
inst_log="$(mktemp)"
for pkg in "${PACKAGES[@]}"; do
  if flox install "flox/$pkg" >"$inst_log" 2>&1; then
    echo "  installed: flox/$pkg"
  else
    echo "  FAILED:    flox/$pkg" >&2
    sed 's/^/      | /' "$inst_log" >&2
    FAILED+=("$pkg")
  fi
done
rm -f "$inst_log"

echo ""
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo "coexist FAILED: ${#FAILED[@]}/${#PACKAGES[@]} packages could not be" \
       "installed into one environment:"
  printf '  - %s\n' "${FAILED[@]}"
  exit 1
fi

echo "coexist OK: all ${#PACKAGES[@]} packages installed into one Flox environment"
exit 0
