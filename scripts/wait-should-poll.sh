#!/usr/bin/env bash
#
# Decide whether a wait job needs to poll, based on which
# files changed. Reads newline-separated paths from stdin.
# Prints "true" if polling is needed, "false" otherwise.
#
# Usage:
#   git diff --name-only BASE HEAD | wait-should-poll.sh envs
#   git diff --name-only BASE HEAD | wait-should-poll.sh packages
#
# Run from the repository root (envs mode discovers env names from
# the tree: top-level directories containing .flox/env/manifest.toml
# whose name does not end in -demo — same rule as discover-envs.sh).
set -euo pipefail

mode="${1:-}"

case "$mode" in
  envs|packages) ;;
  *)
    echo "usage: $0 <envs|packages>" >&2
    echo "unknown mode: '$mode'" >&2
    exit 2
    ;;
esac

# Read changed paths from stdin into an array (drop blanks).
changed=()
while IFS= read -r line; do
  [ -n "$line" ] && changed+=("$line")
done

if [ "${#changed[@]}" -eq 0 ]; then
  echo "false"
  exit 0
fi

if [ "$mode" = "packages" ]; then
  for p in "${changed[@]}"; do
    case "$p" in
      .flox/pkgs/*) echo "true"; exit 0 ;;
    esac
  done
  echo "false"
  exit 0
fi

# envs mode: derive env names from the tree (same rule as
# discover-envs.sh) — every top-level directory containing
# .flox/env/manifest.toml whose name does not end in -demo.
envs=()
for d in */; do
  name="${d%/}"
  case "$name" in *-demo) continue ;; esac
  [ -f "$name/.flox/env/manifest.toml" ] && envs+=("$name")
done

for p in "${changed[@]}"; do
  case "$p" in
    flake.nix|flake.lock) echo "true"; exit 0 ;;
    scripts/*) echo "true"; exit 0 ;;
    .github/workflows/environment.yml) echo "true"; exit 0 ;;
    .github/workflows/ci_envs.yml) echo "true"; exit 0 ;;
    .flox/pkgs/basic-memory/*) echo "true"; exit 0 ;;
    .flox/pkgs/honcho/*) echo "true"; exit 0 ;;
    .flox/pkgs/review-skills/*) echo "true"; exit 0 ;;
    .flox/pkgs/skill-validator/*) echo "true"; exit 0 ;;
    .flox/pkgs/claudelint/*) echo "true"; exit 0 ;;
    .flox/pkgs/cclint/*) echo "true"; exit 0 ;;
    .flox/pkgs/skill-tools/*) echo "true"; exit 0 ;;
    .flox/pkgs/agnix/*) echo "true"; exit 0 ;;
    .flox/pkgs/skillcheck/*) echo "true"; exit 0 ;;
    .flox/pkgs/skillspector/*) echo "true"; exit 0 ;;
    *)
      for env in "${envs[@]}"; do
        case "$p" in
          "$env"/*|"$env"-demo/*) echo "true"; exit 0 ;;
        esac
      done
      ;;
  esac
done

echo "false"
