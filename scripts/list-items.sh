#!/usr/bin/env bash
# Enumerate every item in this repo as <kind>:<name>, one
# per line, sorted lexicographically. Item = directory
# with a meta.yaml.
#
# Envs:     <NAME>/meta.yaml         -> env:<NAME>
#           (NAME must not end in `-demo` and must not be
#           a dotted dir or special build/config dir.)
# Packages: .flox/pkgs/<NAME>/meta.yaml -> pkg:<NAME>

set -euo pipefail

ROOT="${REPO_ROOT:-$(pwd)}"

(
  cd "$ROOT" || exit 0

  # envs
  for d in */; do
    name="${d%/}"
    case "$name" in
      .*|site|scripts|node_modules) continue ;;
    esac
    case "$name" in *-demo) continue ;; esac
    [ -f "$name/meta.yaml" ] || continue
    echo "env:$name"
  done

  # packages
  if [ -d ".flox/pkgs" ]; then
    for d in .flox/pkgs/*/; do
      [ -d "$d" ] || continue
      name="$(basename "$d")"
      [ -f "$d/meta.yaml" ] || continue
      echo "pkg:$name"
    done
  fi
) | sort -u
