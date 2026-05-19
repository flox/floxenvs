#!/usr/bin/env bash
# Tests for scripts/list-items.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/../list-items.sh"

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
mkdir -p "$TMP/claude" "$TMP/claude-demo" "$TMP/langchain"
mkdir -p "$TMP/.flox/pkgs/ollama" "$TMP/.flox/pkgs/codex"
mkdir -p "$TMP/site" "$TMP/scripts"
echo "kind: env"  > "$TMP/claude/meta.yaml"
echo "kind: env"  > "$TMP/langchain/meta.yaml"
echo "kind: pkg"  > "$TMP/.flox/pkgs/ollama/meta.yaml"
echo "kind: pkg"  > "$TMP/.flox/pkgs/codex/meta.yaml"

out=$(cd "$TMP" && "$HELPER" | sort)
expected=$(printf 'env:claude\nenv:langchain\npkg:codex\npkg:ollama')
assert_eq "list items (sorted)" "$expected" "$out"

mkdir -p "$TMP/secret"
out=$(cd "$TMP" && "$HELPER" | sort)
assert_eq "no meta.yaml -> hidden" "$expected" "$out"

mkdir -p "$TMP/symphony-demo"
out=$(cd "$TMP" && "$HELPER" | sort)
assert_eq "demo dir excluded" "$expected" "$out"

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
