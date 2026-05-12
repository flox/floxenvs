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

# `symphony` is an Elixir escript; calling it without
# the acknowledgement flag prints the guardrails warning
# and exits non-zero. That confirms the binary is wired
# correctly without booting the orchestrator. We capture
# output through a subshell so the non-zero exit doesn't
# trip `set -eo pipefail`.
symphony_out=$(symphony 2>&1 || true)
echo "$symphony_out" | grep -q 'guardrails' \
  || { echo "Error: symphony self-check did not print guardrails warning"; exit 1; }
echo ">>> symphony self-check ... OK"
echo ">>> codex version:    $(codex --version 2>&1 | head -1)"

echo ">>> symphony environment is working"
