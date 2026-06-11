# Skills Review

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Freview-skills%2Fdevcontainer.json)

Unified 0-100 quality score for
[Claude Code](https://docs.claude.com/en/docs/claude-code)
skills and agents.

`review-skills` detects whether a path is a skill
(`SKILL.md`) or an agent (`.md` with agent frontmatter),
runs a per-kind ensemble of linters, normalizes each tool
to 0-100, and fuses the results into four dimensions plus a
security cap and a status pill. Everything runs locally and
offline; an optional behavioral stage uses
[promptfoo](https://www.promptfoo.dev/).

`review-skills` is a self-contained Go CLI. Alongside the
`lint`/`review`/`audit` commands it adds `report` (raw
per-tool output) and `doctor` (tool availability + a smoke
test + the resolved per-kind ensemble), plus `--findings` on
`audit` (a normalized findings array) and `--tools`/`--disable`
to choose which quality tools run.

## Quick start

Include in your manifest:

```toml
[include]
environments = ["flox/review-skills"]
```

During local development, include the in-repo copy by
directory instead:

```toml
[include]
environments = [{ dir = "../review-skills" }]
```

Or activate directly:

```bash
flox activate -r flox/review-skills
review-skills audit path/to/skill
```

## What it provides

- `review-skills` — the runner (skill/agent detection,
  ensemble scoring, `metrics.json` output)
- `skill-tools` — ESLint + Lighthouse-style skill scorer
- `claudelint` — whole-project Claude Code linter
- `cclint` — agent/command/settings/CLAUDE.md linter
- `skill-validator` — `SKILL.md` structure + token budgets
- `agnix` — linter for skills, agents, CLAUDE.md, MCP, hooks
- `skillcheck` — SAST scanner for `SKILL.md` bodies (SARIF)
- `promptfoo` — optional behavioral eval harness

## Commands

| Command | Description |
| ------- | ----------- |
| `review-skills lint <path>` | Deterministic structural gate (exit 0/1) |
| `review-skills review <path>` | Quality-only score |
| `review-skills audit <path>` | Full 0-100 `metrics.json` |
| `review-skills report <path>` | Raw per-tool output for the kind |
| `review-skills doctor` | Tool availability + smoke + resolved ensemble |
| `review-skills version` | Print the semver |

Flags:

- `--json` — emit machine-readable JSON instead of a
  human one-liner.
- `--kind skill\|agent` — force the artifact kind instead
  of auto-detecting.
- `--threshold <n>` — exit nonzero if the overall (or
  quality, for `review`) score is below `<n>`.
- `--findings` — on `audit`, include a normalized findings
  array (severity / tool / rule / message / file / line)
  fused across every tool.
- `--tools <list>` — restrict the quality ensemble to the
  named tools (comma-separated).
- `--disable <list>` — drop the named tools from the quality
  ensemble; the remaining weights re-normalize automatically.
- `--with-behavioral` — also run a promptfoo behavioral
  eval (see below).

Examples:

```bash
# Human-readable audit of a skill directory
review-skills audit path/to/my-skill

# JSON audit of an agent, gated at 70
review-skills audit --json --threshold 70 path/to/agent.md

# Audit with the normalized findings array
review-skills audit --json --findings path/to/my-skill

# Restrict the ensemble, or drop a tool
review-skills audit --tools skill-tools,skill-validator path/to/my-skill
review-skills audit --disable claudelint path/to/my-skill

# Just the deterministic gate (CI pre-check)
review-skills lint path/to/my-skill

# Raw per-tool output, and an environment health check
review-skills report path/to/my-skill
review-skills doctor
```

## The four dimensions

`audit` fuses the ensemble into one overall score:

- **quality (35%)** — weighted ensemble of the linters for
  the artifact kind (skills: skill-tools 40 / skill-validator
  30 / claudelint 30; agents: claudelint 50 / agnix 30 /
  cclint 20).
- **reliability (35%)** — the deterministic gate
  (frontmatter + structure), floored by claudelint
  conformance.
- **security (20%)** — `skillcheck` SARIF severity. The
  highest finding also caps the overall score: HIGH caps at
  75, CRITICAL caps at 50.
- **impact (10%)** — behavioral signal. Estimated at 70
  unless `--with-behavioral` runs a real promptfoo eval.

The overall score maps to a status pill: `stable` (>=80),
`warn` (>=60), `risk` (<60).

The runner **fails closed**: if any underlying tool is
missing or crashes, that member scores 0 and is flagged in
the `quality.checks` breakdown rather than being read as a
clean pass.

## Behavioral evals

`--with-behavioral` invokes `promptfoo eval`, which calls an
LLM provider and therefore needs a provider API key in the
environment (e.g. `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`).
Without `--with-behavioral`, the impact dimension is
estimated and no network call is made.

## Configuration

- `REVIEW_SKILLS_QUICK_VALIDATE` — path to the
  `quick_validate.py` used by the skill gate. The env sets
  this to the vendored
  [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator)
  copy on activate. If unset (or PyYAML is unavailable) the
  runner falls back to a dependency-free inline frontmatter
  check.
- `REVIEW_SKILLS_DRY_RUN=1` — make every tool adapter return
  a fixed stub score instead of invoking the real CLI (used
  by the package's own tests).

## See also

- [review-skills-demo](../review-skills-demo/) — interactive
  demo with sample skills and agents
