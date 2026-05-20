#!/usr/bin/env bash
# Run each fixture against the rule set and diff the IDs
# of findings against the matching .expected file.
# Gracefully skips when semgrep or jq is absent from PATH.
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v semgrep &>/dev/null; then
  echo "SKIP: semgrep not found on PATH (install via 'pip install semgrep' or 'nix shell nixpkgs#semgrep')"
  exit 0
fi

if ! command -v jq &>/dev/null; then
  echo "SKIP: jq not found on PATH"
  exit 0
fi

fail=0

for fixture in tests/*.sh tests/*.toml; do
  base=${fixture%.*}
  expected="${base}.expected"
  if [[ ! -f $expected ]]; then
    echo "MISSING EXPECTED: $expected" >&2
    fail=1
    continue
  fi

  actual=$(semgrep --quiet --config flox.yaml --json "$fixture" \
    | jq -r '.results[].check_id' \
    | sed 's|^.*\.||' \
    | sort -u)

  expected_sorted=$(sort -u "$expected" | sed '/^$/d')

  if ! diff -u \
       <(printf '%s\n' "$expected_sorted") \
       <(printf '%s\n' "$actual"); then
    echo "FAIL: $fixture" >&2
    fail=1
  else
    echo "OK:   $fixture"
  fi
done

exit "$fail"
