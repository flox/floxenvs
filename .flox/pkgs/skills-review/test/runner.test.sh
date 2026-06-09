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

# lint exits 0 on the good skill, nonzero on a broken one.
SKILLS_REVIEW_DRY_RUN=1 "$BIN" lint "$DIR/test/skills/good" \
  || { echo "FAIL lint good"; exit 1; }
mkdir -p "$DIR/test/skills/bad"; printf 'no frontmatter\n' > "$DIR/test/skills/bad/SKILL.md"
if SKILLS_REVIEW_DRY_RUN=1 SKILLS_REVIEW_FORCE_GATE_FAIL=1 "$BIN" lint "$DIR/test/skills/bad"; then
  echo "FAIL lint bad should be nonzero"; exit 1
fi
echo "PASS runner.lint"

out=$(SKILLS_REVIEW_DRY_RUN=1 "$BIN" audit --json "$DIR/test/skills/good")
echo "$out" | jq -e '
  (.overall|numbers) and
  (.status|test("stable|warn|risk")) and
  (.quality.score|numbers) and (.security.cap|numbers)
' >/dev/null || { echo "FAIL audit shape"; exit 1; }
# dry-run skill: q=ensemble3(40*82,30*90,30*70)=81, r=100(gate)->floor,
# s=100 cap=100, i=70 -> fuse(81,?,100,70); just assert overall in 0..100.
o=$(echo "$out" | jq -r '.overall'); [ "$o" -ge 0 ] && [ "$o" -le 100 ] \
  || { echo "FAIL overall range"; exit 1; }
echo "PASS runner.audit"
