# Skills Review Demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fskills-review-demo%2Fdevcontainer.json)

Interactive demo of the
[skills-review](../skills-review/) environment — a unified
0-100 quality score for Claude Code skills and agents, with
a styled welcome banner and ready-to-score sample artifacts.

## Quick start

```bash
flox activate -r flox/skills-review-demo
```

On activate you get a banner and a cheat sheet. Then score
the bundled samples:

```bash
# A clean, well-formed skill — scores well (stable-to-warn)
skills-review audit samples/good-skill

# A deliberately broken skill — scores low
skills-review audit samples/bad-skill

# A clean agent — auto-detected as an agent
skills-review audit samples/good-agent.md
```

Add `--json` for machine-readable output:

```bash
skills-review audit --json samples/good-skill | jq .
```

## Walkthrough

1. **Score the good skill.** `skills-review audit
   samples/good-skill` runs the skill ensemble (skill-tools,
   skill-validator, claudelint), the structural gate,
   skillcheck, and an estimated impact, then fuses them into
   one overall score with a `stable`/`warn`/`risk` pill.
2. **Compare with the broken skill.**
   `samples/bad-skill/SKILL.md` is missing its `description`,
   uses a non-kebab name that overruns the 64-character
   limit, and has a one-word body. It fails the structural
   gate and scores clearly lower — exactly what the demo
   `test.sh` asserts (good overall > bad overall).
3. **Score the agent.** `samples/good-agent.md` carries
   agent frontmatter (`model`, `tools`, a "use proactively"
   description), so the runner auto-detects `kind: agent` and
   runs the agent ensemble (claudelint, agnix, cclint)
   instead.
4. **Inspect a dimension.** Use `--json` and `jq` to read the
   `quality.checks` breakdown, the `security.cap`/`severity`,
   and the `reliability` gate result.

## What it provides

Everything from [skills-review](../skills-review/) plus:

- `gum` — styled terminal UI for the welcome banner
- `samples/good-skill/` — a clean, well-formed skill
- `samples/bad-skill/` — a deliberately broken skill
- `samples/good-agent.md` — a clean agent

## See also

- [skills-review](../skills-review/) — minimal environment
  for `[include]`
