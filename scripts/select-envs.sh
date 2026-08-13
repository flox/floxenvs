#!/usr/bin/env bash
# select-envs.sh — select environments to run CI for.
#
#   scripts/select-envs.sh [single-env] < changed-file-paths
#   scripts/select-envs.sh --all
#
# stdin: newline-separated changed file paths (ignored when
#        single-env or --all is given).
# arg1:  optional single environment name — output exactly that env
#        (workflow_dispatch override). "--all" selects every
#        environment unconditionally, without reading stdin.
# stdout: compact JSON array of environment names.
#
# Selection rules:
#   1. arg1 = --all                -> every env
#   2. arg1 = <env>                -> exactly that env
#   3. any SHARED path changed     -> all envs
#   4. .flox/pkgs/<p>/ changed and some env's manifest.toml
#      (or its -demo counterpart) declares
#      pkg-path = "flox/<p>"       -> that env (tree-derived,
#      no hardcoded package list)
#   5. otherwise                   -> envs whose <env>/** or
#                                     <env>-demo/** changed
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

if [ "$single" = "--all" ]; then
  printf '%s\n' "${envs[@]}" | jq -Rc . | jq -sc .
  exit 0
fi

if [ -n "$single" ]; then
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

selected=()

is_selected() {
  local target="$1" e
  for e in "${selected[@]:-}"; do
    [ "$e" = "$target" ] && return 0
  done
  return 1
}

# ── .flox/pkgs/<p>/ changes: map to envs whose manifest (or its
#    -demo counterpart) declares pkg-path = "flox/<p>" ──
while IFS= read -r p; do
  case "$p" in
    .flox/pkgs/*)
      pkgname="${p#.flox/pkgs/}"
      pkgname="${pkgname%%/*}"
      [ -z "$pkgname" ] && continue
      for e in "${envs[@]}"; do
        is_selected "$e" && continue
        for manifest in "$e/.flox/env/manifest.toml" \
          "$e-demo/.flox/env/manifest.toml"; do
          if [ -f "$manifest" ] \
            && grep -q "\"flox/$pkgname\"" "$manifest"; then
            selected+=("$e")
            break
          fi
        done
      done
      ;;
  esac
done <<<"$changed"

# ── Per-env selection: <env>/** or <env>-demo/** changed ──
for e in "${envs[@]}"; do
  is_selected "$e" && continue
  if echo "$changed" | grep -qE "^$e(-demo)?/"; then
    selected+=("$e")
  fi
done

if [ ${#selected[@]} -eq 0 ]; then
  echo "[]"
else
  printf '%s\n' "${selected[@]}" | jq -Rc . | jq -sc .
fi
