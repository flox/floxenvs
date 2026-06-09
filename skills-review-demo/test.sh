#!/usr/bin/env bash

set -eo pipefail

command_exists() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: '$1' command not found."
    return 1
  fi
  echo ">>> '$1' command exists"
}

# ── Required commands (runner inherited from skills-review) ──
command_exists skills-review
command_exists gum

# ── Sample artifacts present ────────────────────────────────
for f in samples/good-skill/SKILL.md samples/bad-skill/SKILL.md \
         samples/good-agent.md; do
  if [ ! -f "$f" ]; then
    echo "Error: sample '$f' missing."
    exit 1
  fi
done
echo ">>> sample artifacts present"

# ── Scoring contrast: the clean skill must beat the broken one ──
# Real-mode (no SKILLS_REVIEW_DRY_RUN): the bad skill fails the
# structural gate while the good one passes, so good > bad even
# before the scoring tools weigh in.
good=$(skills-review audit --json samples/good-skill | jq -r '.overall')
bad=$(skills-review audit --json samples/bad-skill | jq -r '.overall')
if [ "$good" -le "$bad" ]; then
  echo "Error: expected good > bad (good=$good bad=$bad)"
  exit 1
fi
echo ">>> demo scores: good=$good bad=$bad (good > bad)"

# ── Agent is detected as an agent ───────────────────────────
kind=$(skills-review audit --json samples/good-agent.md | jq -r '.identity.kind')
if [ "$kind" != "agent" ]; then
  echo "Error: expected agent kind, got '$kind'"
  exit 1
fi
echo ">>> good-agent detected as: $kind"

echo ">>> skills-review-demo environment is working"
