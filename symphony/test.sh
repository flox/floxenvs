#!/usr/bin/env bash
set -eo pipefail

for c in symphony codex git bash; do
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "Error: '$c' command not found."
    exit 1
  fi
  echo ">>> $c ... OK"
done

if [[ ! -f "$SYMPHONY_DATA/WORKFLOW.md" ]]; then
  echo "Error: WORKFLOW.md not generated at \$SYMPHONY_DATA"
  exit 1
fi
echo ">>> WORKFLOW.md ... OK"

# `symphony` is an Elixir escript; calling it with no
# args prints the guardrails warning and exits 0. That
# both confirms the binary is wired correctly and avoids
# accidentally booting the orchestrator from a test.
symphony 2>&1 | grep -q 'guardrails' \
  || { echo "Error: symphony self-check did not print guardrails warning"; exit 1; }
echo ">>> symphony self-check ... OK"
echo ">>> codex version:    $(codex --version 2>&1 | head -1)"

echo ">>> symphony environment is working"
