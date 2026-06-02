#!/usr/bin/env bash
#
# Compute the reliability section for an item:
# CI green streak (days), last-test timestamp (ISO 8601
# date, no time), lockfile/hashes freshness flag,
# average test duration. Output is a JSON object.
#
# Usage: compute-reliability.sh <kind> <name>
#
# Env:
#   GITHUB_REPOSITORY  org/repo (default: flox/floxenvs)
#   GITHUB_TOKEN       used by gh when available

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/sh-helpers.sh"
ROOT="${REPO_ROOT:-$(sh_repo_root)}"

KIND="${1:?kind}"
NAME="${2:?name}"
REPO="${GITHUB_REPOSITORY:-flox/floxenvs}"

case "$KIND" in
  env) workflow_file="ci_${NAME}.yml" ;;
  pkg) workflow_file="ci_pkgs.yml" ;;
  *)   echo "unknown kind: $KIND" >&2; exit 2 ;;
esac

dir=$(sh_item_dir "$KIND" "$NAME")
lockfile_fresh=false
case "$KIND" in
  env)
    lock="$ROOT/$dir/.flox/env/manifest.lock"
    if [ -f "$lock" ]; then
      lockfile_fresh=true
    fi
    ;;
  pkg)
    h="$ROOT/$dir/hashes.json"
    if [ -f "$h" ] && jq -e '.version' "$h" >/dev/null 2>&1; then
      lockfile_fresh=true
    fi
    ;;
esac

note=""
runs_json=""
if command -v gh >/dev/null 2>&1 \
   && [ -n "${GITHUB_TOKEN:-}" ]; then
  if ! runs_json=$(gh api --method GET \
        "repos/${REPO}/actions/workflows/${workflow_file}/runs?branch=main&per_page=30" \
        2>/dev/null); then
    note="gh api failed; using defaults"
    # On failure (e.g. 404 for an item without a ci_<name>.yml, like an
    # env that has no dedicated workflow) gh still writes the error JSON
    # body to stdout. Clear it so the non-empty guard below skips the
    # parsing that would otherwise hit `.workflow_runs[]` on null.
    runs_json=""
  fi
else
  note="no GITHUB_TOKEN; reliability defaults to neutral"
fi

streak=0
last_at=""
avg_s=0
score=80

if [ -n "$runs_json" ]; then
  # Count consecutive successful main runs from newest.
  streak=$(echo "$runs_json" | jq '
    [(.workflow_runs // [])[]
     | select(.head_branch == "main")
     | .conclusion]
    | (. + ["FAIL"])
    | (index("failure") // index("FAIL"))
  ')
  last_at=$(echo "$runs_json" | jq -r '
    [(.workflow_runs // [])[] | select(.head_branch == "main")][0]
    .created_at // ""
  ' | cut -d T -f1)
  avg_s=$(echo "$runs_json" | jq '
    [(.workflow_runs // [])[]
     | select(.head_branch == "main")
     | (((.updated_at | fromdateiso8601))
        - ((.created_at | fromdateiso8601)))]
    | (add // 0) / (length | if . == 0 then 1 else . end)
    | floor
  ')

  # Score = 50 base + min(streak*5, 50)
  add=$(( streak * 5 ))
  if [ "$add" -gt 50 ]; then add=50; fi
  score=$(( 50 + add ))
  if ! "$lockfile_fresh"; then
    score=$(( score - 10 ))
  fi
fi

jq -nc \
  --argjson streak "$streak" \
  --arg     last   "$last_at" \
  --argjson fresh  "$lockfile_fresh" \
  --argjson dur    "$avg_s" \
  --argjson score  "$score" \
  --arg     note   "$note" \
  '{
    ci_green_streak_days: $streak,
    last_test_at: $last,
    lockfile_fresh: $fresh,
    test_duration_s: $dur,
    score: $score,
    note: $note,
  }'
