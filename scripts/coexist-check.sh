#!/usr/bin/env bash
# coexist-check.sh — prove that ALL skill packages + every agent runtime +
# every audit tool can be installed into ONE Flox environment.
#
# This tests FLOX, not Nix: it builds every package FROM SOURCE with `flox
# build`, then creates a throwaway Flox environment and runs `flox install
# ./result-<package>` for each build output, one at a time. `flox install`
# rejects a package that conflicts with one already in the environment (the
# original bug: four python skills each shipped bin/python3 and clashed on
# $FLOX_ENV/bin/python3). If every install succeeds, the whole set coexists
# in a single Flox environment. The throwaway environment and the result
# symlinks are removed at the end, pass or fail.
#
# Why build-then-install instead of installing catalog pkg-paths: installing
# `flox/<pkg>` resolves from the CATALOG, i.e. the PUBLISHED packages — so the
# check would lag a source fix until the package is republished (the
# chicken-and-egg where the fix is in the tree but the catalog still ships the
# colliding bin/python3). Building from source and installing the local
# ./result-<pkg> validates THIS checkout, so a source fix turns the check
# green immediately, before any publish.
#
# Usage (plain shell, NOT inside `flox activate`):
#   bash scripts/coexist-check.sh
# Exit 0 + "coexist OK" if every package builds and installs; non-zero
# (listing the packages that failed to build or to install) otherwise.

set -uo pipefail

# ── Locate the repo root (to read the skill package list and to build) ──
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

# ── Compute the target package list (.flox/pkgs dir names) ──
# Every skill package: those whose default.nix uses flox_agent_layout.
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

# ── Build every package from source; collect the result symlink paths ──
# `flox build <pkg>` writes ./result-<pkg> (and ./result-<pkg>-log) into the
# repo root. Build for the native system — the CI job runs this on linux.
BUILT=()          # package names that built, parallel to RESULTS
RESULTS=()        # absolute ./result-<pkg> paths to install
BUILD_FAILED=()
build_log="$(mktemp)"
cleanup() {
  # Remove the throwaway environment, its directory, and the result symlinks
  # this script produced — pass or fail.
  [ -n "${ENV_DIR:-}" ] && flox delete -d "$ENV_DIR" -f >/dev/null 2>&1 || true
  [ -n "${ENV_DIR:-}" ] && rm -rf "$ENV_DIR"
  local pkg
  for pkg in "${PACKAGES[@]}"; do
    rm -f "$REPO_ROOT/result-$pkg" "$REPO_ROOT/result-$pkg-log"
  done
  rm -f "$build_log"
}
trap cleanup EXIT

cd "$REPO_ROOT"
echo "Building ${#PACKAGES[@]} packages from source ..."
for pkg in "${PACKAGES[@]}"; do
  if flox build "$pkg" >"$build_log" 2>&1; then
    echo "  built:     $pkg"
    BUILT+=("$pkg")
    RESULTS+=("$REPO_ROOT/result-$pkg")
  else
    echo "  BUILD FAILED: $pkg" >&2
    sed 's/^/      | /' "$build_log" >&2
    BUILD_FAILED+=("$pkg")
  fi
done

# ── Create a throwaway Flox environment and change into it ──
ENV_DIR="$(mktemp -d)"
cd "$ENV_DIR"
echo "Creating throwaway environment in $ENV_DIR ..."
if ! flox init >/dev/null 2>&1; then
  echo "ERROR: flox init failed in $ENV_DIR" >&2
  exit 2
fi

# ── Install every built package, one at a time, into the single env ──
# `flox install ./result-<pkg>` fails if a package conflicts with one already
# installed, so a per-package loop pinpoints exactly which package the
# environment rejects.
INSTALL_FAILED=()
inst_log="$(mktemp)"
for i in "${!BUILT[@]}"; do
  pkg="${BUILT[$i]}"
  result="${RESULTS[$i]}"
  if flox install "$result" >"$inst_log" 2>&1; then
    echo "  installed: $pkg"
  else
    echo "  INSTALL FAILED: $pkg" >&2
    sed 's/^/      | /' "$inst_log" >&2
    INSTALL_FAILED+=("$pkg")
  fi
done
rm -f "$inst_log"

# ── List everything installed into the single environment ──
echo ""
echo "Packages in the coexistence environment:"
flox list

echo ""
status=0
if [ "${#BUILD_FAILED[@]}" -gt 0 ]; then
  echo "coexist FAILED: ${#BUILD_FAILED[@]}/${#PACKAGES[@]} packages did not build:"
  printf '  - %s\n' "${BUILD_FAILED[@]}"
  status=1
fi
if [ "${#INSTALL_FAILED[@]}" -gt 0 ]; then
  echo "coexist FAILED: ${#INSTALL_FAILED[@]}/${#BUILT[@]} built packages could" \
       "not be installed into one environment:"
  printf '  - %s\n' "${INSTALL_FAILED[@]}"
  status=1
fi
[ "$status" -ne 0 ] && exit 1

echo "coexist OK: all ${#PACKAGES[@]} packages built and installed into one Flox environment"
exit 0
