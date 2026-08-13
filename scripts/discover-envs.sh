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

if [ ${#envs[@]} -eq 0 ]; then
  echo "ERROR: no environments found in repo" >&2
  exit 1
fi

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
  '^(flake\.nix$|flake\.lock$|scripts/|\.github/workflows/environment\.yml$|\.github/workflows/ci_envs\.yml$)'; then
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
