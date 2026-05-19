#!/usr/bin/env bash
#
# Run evals.yaml for an item. Emits a JSON object with
# pass/total counts, a score (round-down percentage),
# and per-case results.
#
# Usage: run-flox-evals.sh <kind> <name>
# Env:
#   FLOX_EVAL_DRY_RUN=1   Skip `flox activate -- bash -c`
#                         and run the case command in the
#                         current shell. For tests.
#
# evals.yaml shape (subset):
#   cases:
#     - id: foo
#       cmd: "claude --help"
#       assert:
#         exit_code: 0
#         stdout_matches: "^Usage:"
#         stdout_contains: ["foo", "bar"]
#         max_duration_s: 10

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/lib/sh-helpers.sh"
ROOT="${REPO_ROOT:-$(sh_repo_root)}"

KIND="${1:?kind}"
NAME="${2:?name}"
dir=$(sh_item_dir "$KIND" "$NAME")
evals_file="$ROOT/$dir/evals.yaml"

if [ ! -f "$evals_file" ]; then
  jq -nc '{pass:0, total:0, score:null, cases:[]}'
  exit 0
fi

run_case() {
  local cmd="$1"
  if [ "${FLOX_EVAL_DRY_RUN:-}" = "1" ]; then
    bash -c "$cmd"
  else
    case "$KIND" in
      env) ( cd "$ROOT/$dir" \
             && flox activate -- bash -c "$cmd" ) ;;
      pkg) ( cd "$ROOT" \
             && flox activate --dir . -- bash -c "$cmd" ) ;;
    esac
  fi
}

cases_json=$(yq -o=json '.cases' "$evals_file")
total=$(echo "$cases_json" | jq 'length')
pass=0
case_results="[]"

for i in $(seq 0 $((total - 1))); do
  id=$(echo "$cases_json"       | jq -r ".[$i].id")
  cmd=$(echo "$cases_json"      | jq -r ".[$i].cmd")
  exp_code=$(echo "$cases_json" | jq -r ".[$i].assert.exit_code // 0")
  out_match=$(echo "$cases_json"  | jq -r ".[$i].assert.stdout_matches // empty")
  out_contains_json=$(echo "$cases_json" \
    | jq -r ".[$i].assert.stdout_contains // [] | .[]")
  max_dur=$(echo "$cases_json"  | jq -r ".[$i].assert.max_duration_s // 30")

  start=$(date +%s)
  set +e
  out=$(run_case "$cmd" 2>&1)
  code=$?
  set -e
  dur=$(( $(date +%s) - start ))

  ok=true
  notes=()
  if [ "$code" != "$exp_code" ]; then
    ok=false
    notes+=("exit_code=$code want=$exp_code")
  fi
  if [ -n "$out_match" ] && ! echo "$out" | grep -Eq "$out_match"; then
    ok=false
    notes+=("stdout_matches failed")
  fi
  if [ -n "$out_contains_json" ]; then
    while IFS= read -r needle; do
      [ -z "$needle" ] && continue
      if ! echo "$out" | grep -qF "$needle"; then
        ok=false
        notes+=("stdout_contains '$needle' failed")
      fi
    done <<< "$out_contains_json"
  fi
  if [ "$dur" -gt "$max_dur" ]; then
    ok=false
    notes+=("duration=$dur > max=$max_dur")
  fi

  $ok && pass=$((pass + 1))
  note=$(printf '%s; ' "${notes[@]:-}" | sed 's/; $//')
  case_json=$(jq -nc \
    --arg id "$id" \
    --argjson pass "$ok" \
    --argjson duration "$dur" \
    --arg note "$note" \
    '{id:$id, pass:$pass, duration_s:$duration, note:$note}')
  case_results=$(echo "$case_results" \
    | jq --argjson c "$case_json" '. + [$c]')
done

score="null"
if [ "$total" -gt 0 ]; then
  score=$(( pass * 100 / total ))
fi

jq -nc \
  --argjson pass "$pass" \
  --argjson total "$total" \
  --argjson score "$score" \
  --argjson cases "$case_results" \
  '{pass:$pass, total:$total, score:$score, cases:$cases}'
