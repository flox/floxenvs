---
name: good-skill
description: Use when you need a tidy, well-formed example skill to exercise the review-skills e2e suite end to end.
---

# Good skill

A minimal, well-formed skill used as a clean fixture for the
review-skills end-to-end tests. It has valid frontmatter, a clear
description that states when to use it, and a body with real structure.

## Usage

Run `review-skills audit ./good-skill` to score this skill. The audit
should return a healthy overall score and a stable or warn status.

## Instructions

1. Read the target file before changing anything.
2. Make the smallest change that satisfies the request.
3. Report the result clearly and concisely.

## Examples

```bash
review-skills audit ./good-skill
review-skills lint ./good-skill
```

## Notes

Keep the skill focused. A good skill does one thing well and explains
exactly when it applies so the model can trigger it reliably.
