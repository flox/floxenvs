#!/usr/bin/env bash
# Tests for scripts/lib/sh-helpers.sh and
# scripts/lib/metrics-defaults.sh.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
# shellcheck disable=SC1091
. "$ROOT/lib/sh-helpers.sh"

PASS=0
FAIL=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "ok - $label"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL - $label"
    echo "  expected: $expected"
    echo "  actual:   $actual"
  fi
}

# ── sh_check_json shape ──────────────────────────────────
out=$(sh_check_json "has-readme" true 5)
assert_eq "check_json basic" \
  '{"id":"has-readme","pass":true,"weight":5}' "$out"

out=$(sh_check_json "silent-hook" false 10 "echo found")
assert_eq "check_json with note" \
  '{"id":"silent-hook","pass":false,"weight":10,"note":"echo found"}' \
  "$out"

# ── sh_aggregate_quality scoring ─────────────────────────
score=$(printf '%s\n' \
  '{"id":"a","pass":true,"weight":10}' \
  '{"id":"b","pass":false,"weight":10}' \
  '{"id":"c","pass":true,"weight":5}' \
  | sh_aggregate_quality | jq -r '.score')
assert_eq "aggregate weighted score" "60" "$score"

# ── sh_aggregate_quality empty ───────────────────────────
score=$(printf '' | sh_aggregate_quality | jq -r '.score')
assert_eq "aggregate empty score" "0" "$score"

# ── sh_item_dir ──────────────────────────────────────────
assert_eq "item_dir env"  "claude" "$(sh_item_dir env claude)"
assert_eq "item_dir pkg"  ".flox/pkgs/ollama" \
  "$(sh_item_dir pkg ollama)"

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
