#!/usr/bin/env bash
# Tests for scripts/filter-item-paths.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/../filter-item-paths.sh"

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
mkdir -p "$TMP/claude" "$TMP/.flox/pkgs/ollama"
echo "kind: env" > "$TMP/claude/meta.yaml"
echo "kind: pkg" > "$TMP/.flox/pkgs/ollama/meta.yaml"

run() {
  ( cd "$TMP" && REPO_ROOT="$TMP" "$HELPER" ) <<<"$1"
}

out=$(run "claude/README.md" | sort -u)
assert_eq "env file -> env:claude" "env:claude" "$out"

out=$(run "claude-demo/README.md" | sort -u)
assert_eq "demo file -> env:claude" "env:claude" "$out"

out=$(run ".flox/pkgs/ollama/upgrade.sh" | sort -u)
assert_eq "pkg file -> pkg:ollama" "pkg:ollama" "$out"

out=$(printf '.gitleaks.toml\nscripts/lib/metrics-defaults.sh\n' \
        | ( cd "$TMP" && REPO_ROOT="$TMP" "$HELPER" ) | sort -u)
expected=$(printf 'env:claude\npkg:ollama')
assert_eq "shared-infra -> all items" "$expected" "$out"

out=$(printf '.website/src/components/ItemCard.astro\n' \
        | ( cd "$TMP" && REPO_ROOT="$TMP" "$HELPER" ) | sort -u)
assert_eq "site-only -> no items" "" "$out"

out=$(printf 'claude/test.sh\n.flox/pkgs/ollama/default.nix\n' \
        | ( cd "$TMP" && REPO_ROOT="$TMP" "$HELPER" ) | sort -u)
expected=$(printf 'env:claude\npkg:ollama')
assert_eq "two items in input" "$expected" "$out"

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
