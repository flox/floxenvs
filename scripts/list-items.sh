#!/usr/bin/env bash
# Enumerate every item in this repo as <kind>:<name>, one
# per line, sorted lexicographically. Item = directory
# with a meta.yaml.
#
# Envs:     <NAME>/meta.yaml         -> env:<NAME>
#           (NAME must not end in `-demo` and must not be
#           a dotted dir or special build/config dir.)
# Packages: .flox/pkgs/<NAME>/meta.yaml -> pkg:<NAME>
# Skills:   .flox/pkgs/<NAME>/meta.yaml declaring `subkind: skill`
#           -> skill:<NAME> (in addition to its pkg:<NAME> row).
# Agents:   any `*/agents/*.md` file -> agent:<basename without .md>,
#           excluding test/fixture/testdata trees and node_modules.

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

  # packages (and skills, when meta.yaml declares subkind: skill)
  if [ -d ".flox/pkgs" ]; then
    for d in .flox/pkgs/*/; do
      [ -d "$d" ] || continue
      name="$(basename "$d")"
      [ -f "$d/meta.yaml" ] || continue
      echo "pkg:$name"
      if grep -qE '^subkind:[[:space:]]*skill[[:space:]]*$' "$d/meta.yaml"; then
        echo "skill:$name"
      fi
    done
  fi

  # agents: every `*/agents/*.md` file, skipping vendored / fixture
  # trees so only real, audit-worthy agents are enumerated.
  find . \
    \( -path '*/node_modules/*' \
       -o -path '*/test/*' \
       -o -path '*/tests/*' \
       -o -path '*/testdata/*' \
       -o -path '*/fixtures/*' \
       -o -path '*/e2e/*' \) -prune \
    -o -path '*/agents/*.md' -type f -print 2>/dev/null \
  | while read -r f; do
      base="$(basename "$f" .md)"
      echo "agent:$base"
    done
) | sort -u
