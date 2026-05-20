#!/usr/bin/env bash
# Tests for scripts/run-flox-evals.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/../run-flox-evals.sh"

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

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/sample"
cat > "$TMP/sample/evals.yaml" <<'EOF'
cases:
  - id: echo-runs
    cmd: "true"
    assert:
      exit_code: 0
      max_duration_s: 5

  - id: echo-stdout
    cmd: "printf hello"
    assert:
      exit_code: 0
      stdout_matches: "^hello$"

  - id: should-fail
    cmd: "false"
    assert:
      exit_code: 0
EOF

# Use the dry-runner that does not invoke flox activate.
REPO_ROOT="$TMP" FLOX_EVAL_DRY_RUN=1 "$HELPER" env sample \
  > /tmp/o.json
total=$(jq -r '.total' /tmp/o.json)
pass=$(jq -r '.pass' /tmp/o.json)
score=$(jq -r '.score' /tmp/o.json)
assert_eq "evals total"  "3" "$total"
assert_eq "evals passed" "2" "$pass"
assert_eq "evals score"  "66" "$score"

# No evals.yaml → returns total=0, score=null.
mkdir -p "$TMP/no-evals"
out=$(REPO_ROOT="$TMP" FLOX_EVAL_DRY_RUN=1 "$HELPER" env no-evals)
total=$(echo "$out" | jq -r '.total')
assert_eq "no evals.yaml → total=0" "0" "$total"

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
