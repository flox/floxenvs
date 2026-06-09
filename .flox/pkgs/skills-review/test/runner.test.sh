#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$DIR/bin/skills-review"

# review prints a JSON object with a numeric quality score for a skill.
out=$(SKILLS_REVIEW_DRY_RUN=1 "$BIN" review --json "$DIR/test/skills/good")
echo "$out" | jq -e '.quality.score | numbers' >/dev/null \
  || { echo "FAIL skill quality"; exit 1; }

out=$(SKILLS_REVIEW_DRY_RUN=1 "$BIN" review --json --kind agent "$DIR/test/agents/good.md")
echo "$out" | jq -e '.identity.kind == "agent"' >/dev/null \
  || { echo "FAIL agent kind"; exit 1; }
echo "PASS runner.review"
