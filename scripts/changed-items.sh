#!/usr/bin/env bash
#
# Emit a GitHub-Actions matrix JSON
# ({"include":[{kind, name}, ...]}) describing the items
# that changed since a base SHA.
#
# Inputs (env vars):
#   TRIGGER       workflow_call | workflow_dispatch
#   SHA           target SHA (workflow_call)
#   BASE          base SHA (workflow_call); if missing we
#                 fall back to site-last-deployed
#                 -> root commit.
#   INPUT_ITEMS   workflow_dispatch only:
#                   "all" | "changed" | "<kind>:<name>,..."
#
# Output: matrix JSON on stdout.

set -euo pipefail

ROOT="${REPO_ROOT:-$(pwd)}"
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
TRIGGER="${TRIGGER:-workflow_call}"

resolve_base() {
  local b
  b=$(
    cd "$ROOT" || exit 1
    # --verify --quiet prints nothing and fails cleanly when the tag is
    # missing (e.g. before the first successful deploy); without it,
    # `git rev-parse` echoes the literal ref to stdout, which would then
    # be used as a bogus diff base.
    if sha=$(git rev-parse --verify --quiet \
               "refs/tags/site-last-deployed^{commit}"); then
      echo "$sha"
    else
      git rev-list --max-parents=0 HEAD | head -1
    fi
  )
  echo "$b"
}

emit_from_diff() {
  local base="$1" sha="$2"
  ( cd "$ROOT" && git diff --name-only "$base" "$sha" ) \
    | REPO_ROOT="$ROOT" "$SELF_DIR/filter-item-paths.sh"
}

emit_all() {
  REPO_ROOT="$ROOT" "$SELF_DIR/list-items.sh"
}

emit_explicit() {
  local s="$1"
  echo "$s" | tr ',' '\n' | sed 's/[[:space:]]//g' \
    | grep -E '^(env|pkg):[A-Za-z0-9_.-]+$' || true
}

items=""
case "$TRIGGER" in
  workflow_call)
    base="${BASE:-$(resolve_base)}"
    sha="${SHA:?SHA is required for workflow_call}"
    items=$(emit_from_diff "$base" "$sha")
    ;;
  workflow_dispatch)
    case "${INPUT_ITEMS:-changed}" in
      all)     items=$(emit_all) ;;
      changed) base=$(resolve_base) ;
               items=$(emit_from_diff "$base" "HEAD") ;;
      *)       items=$(emit_explicit "$INPUT_ITEMS") ;;
    esac
    ;;
  *)
    echo "unknown TRIGGER: $TRIGGER" >&2
    exit 2
    ;;
esac

if [ -z "$items" ]; then
  echo '{"include":[]}'
  exit 0
fi

echo "$items" | sort -u | jq -Rsc '
  split("\n")
  | map(select(length > 0))
  | map(capture("^(?<kind>env|pkg):(?<name>.+)$"))
  | { include: . }
'
