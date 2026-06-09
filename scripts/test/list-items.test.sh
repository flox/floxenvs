#!/usr/bin/env bash
# Tests for scripts/list-items.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/../list-items.sh"
REPO="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# A package whose meta.yaml declares `subkind: skill` is also emitted
# as a skill:<name> item (in addition to its pkg:<name> row).
mkdir -p "$TMP/.flox/pkgs/skills-humanizer"
cat > "$TMP/.flox/pkgs/skills-humanizer/meta.yaml" <<'META'
kind: pkg
subkind: skill
name: skills-humanizer
META
out=$(cd "$TMP" && "$HELPER" | sort)
assert_eq "subkind skill -> skill item" "true" \
  "$(echo "$out" | grep -qx 'skill:skills-humanizer' && echo true || echo false)"
assert_eq "subkind skill keeps pkg item" "true" \
  "$(echo "$out" | grep -qx 'pkg:skills-humanizer' && echo true || echo false)"

# An agent .md file under an agents/ dir is emitted as agent:<name>,
# excluding test/fixture/testdata trees.
mkdir -p "$TMP/myenv/.claude/agents"
cat > "$TMP/myenv/.claude/agents/reviewer.md" <<'AGENT'
---
name: reviewer
description: Use proactively to review.
model: sonnet
tools: Read, Grep
---
You review code.
AGENT
mkdir -p "$TMP/.flox/pkgs/foo/test/agents"
echo "fixture" > "$TMP/.flox/pkgs/foo/test/agents/skip.md"
out=$(cd "$TMP" && "$HELPER" | sort)
assert_eq "agent md -> agent item" "true" \
  "$(echo "$out" | grep -qx 'agent:reviewer' && echo true || echo false)"
assert_eq "fixture agent excluded" "true" \
  "$(echo "$out" | grep -q 'agent:skip' && echo false || echo true)"

# Against the real repo root, at least one real skill: item is emitted
# (the repo ships skills-* packages declaring subkind: skill).
real=$(REPO_ROOT="$REPO" "$HELPER" || true)
assert_eq "real repo emits a skill item" "true" \
  "$(echo "$real" | grep -q '^skill:' && echo true || echo false)"

echo "--- $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
