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
# Run from the repository root, or from a directory whose
# .github/workflows/ contains the ci_<name>.yml files (the
# envs mode discovers env names from those filenames).
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

# envs mode: derive env names from ci_<name>.yml filenames.
envs=()
for f in .github/workflows/ci_*.yml; do
  base="$(basename "$f" .yml)"
  name="${base#ci_}"
  if [ "$name" != "pkgs" ]; then
    envs+=("$name")
  fi
done

for p in "${changed[@]}"; do
  case "$p" in
    flake.nix|flake.lock) echo "true"; exit 0 ;;
    scripts/*) echo "true"; exit 0 ;;
    .github/workflows/environment.yml) echo "true"; exit 0 ;;
    .github/workflows/ci_pkgs.yml) ;;
    .github/workflows/ci_*.yml) echo "true"; exit 0 ;;
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
