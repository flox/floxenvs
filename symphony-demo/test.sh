#!/usr/bin/env bash
set -eo pipefail

for c in symphony codex git bash gum; do
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

if ! grep -q '^tracker:' "$SYMPHONY_DATA/WORKFLOW.md"; then
  echo "Error: tracker missing from WORKFLOW.md"
  exit 1
fi
echo ">>> tracker line present"

echo ">>> symphony version: $(symphony version 2>&1 | head -1)"
echo ">>> codex version:    $(codex --version 2>&1 | head -1)"
echo ">>> gum version:      $(gum --version)"

echo ">>> symphony-demo environment is working"
