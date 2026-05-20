#!/usr/bin/env bash
# Tests for scripts/changed-items.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/../changed-items.sh"

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
cd "$TMP" || exit 1
git init -q
git config user.email t@t
git config user.name t

mkdir -p claude langchain .flox/pkgs/ollama scripts
echo "kind: env" > claude/meta.yaml
echo "kind: env" > langchain/meta.yaml
echo "kind: pkg" > .flox/pkgs/ollama/meta.yaml
cp "$SCRIPT_DIR/../filter-item-paths.sh" scripts/
cp "$SCRIPT_DIR/../list-items.sh" scripts/
chmod +x scripts/*.sh
git add .
git commit -q -m initial
BASE=$(git rev-parse HEAD)

echo "diff" >> claude/test.sh
git add . && git commit -q -m claude-change
SHA=$(git rev-parse HEAD)

REPO_ROOT="$TMP" \
  TRIGGER="workflow_call" \
  SHA="$SHA" \
  BASE="$BASE" \
  "$HELPER" > /tmp/m.json
out=$(jq -c '.include | sort_by(.name)' /tmp/m.json)
assert_eq "single env change -> matrix" \
  '[{"kind":"env","name":"claude"}]' "$out"

REPO_ROOT="$TMP" \
  TRIGGER="workflow_dispatch" \
  INPUT_ITEMS="all" \
  "$HELPER" > /tmp/m.json
out=$(jq -c '.include | length' /tmp/m.json)
assert_eq "input=all -> 3 items" "3" "$out"

REPO_ROOT="$TMP" \
  TRIGGER="workflow_dispatch" \
  INPUT_ITEMS="env:claude,pkg:ollama" \
  "$HELPER" > /tmp/m.json
out=$(jq -c '.include | sort_by("\(.kind):\(.name)")' /tmp/m.json)
assert_eq "explicit items list" \
  '[{"kind":"env","name":"claude"},{"kind":"pkg","name":"ollama"}]' \
  "$out"

same_sha="$BASE"
REPO_ROOT="$TMP" \
  TRIGGER="workflow_call" \
  SHA="$same_sha" \
  BASE="$same_sha" \
  "$HELPER" > /tmp/m.json
out=$(jq -c '.include' /tmp/m.json)
assert_eq "no changes -> []" "[]" "$out"

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
