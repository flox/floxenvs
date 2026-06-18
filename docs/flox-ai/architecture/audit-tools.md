# The audit tool ensemble

The audit engine ([audit-engine.md](audit-engine.md)) does not score anything
itself — it orchestrates six external command-line tools, normalises each to
0-100, and fuses them. This page is the reference for those tools, the
per-kind ensembles, and how the dimensions combine.

The tool registry lives in `internal/audit/tools` (one `Tool` entry per
binary). The tools are separate Flox packages (`flox/<tool>`); they must be on
PATH for real scores. `flox-ai doctor` reports which are present, and the
TUI's review flow prompts to install any that are missing.

## The tools

| Tool | Package | Dimension | What it checks | Invocation |
| ---------------- | -------------------- | -------- | -------------- | ---------- |
| `skill-tools` | `flox/skill-tools` | quality | Scores a skill across description quality, instruction clarity, spec compliance, progressive disclosure, and security; emits suggestions | `skill-tools score <path> -f json` |
| `skill-validator` | `flox/skill-validator` | quality | Validates skill structure: unexpected root files, unreferenced assets, missing sections | `skill-validator check <path> -o json` |
| `claudelint` | `flox/claudelint` | quality | Lints the whole Claude Code project surface — skills, agents, settings, hooks, MCP — against conventions (staged in a temp `.claude` project) | `claudelint check-all --format json` |
| `agnix` | `flox/agnix` | quality | Agent-specific linting | `agnix … <path>` |
| `cclint` | `flox/cclint` | quality | Claude Code agent lint (staged) | `cclint --format json` |
| `skillcheck` | `flox/skillcheck` | security | SAST over the `SKILL.md` body — leaked secrets, prompt injection, privilege escalation (SARIF) | `skillcheck <path> --format sarif` |
| `skillspector` | `flox/skillspector` | security | Security scanner over the artifact (SARIF) | `skillspector … <path>` |

## The per-kind quality ensemble

Quality is a weighted ensemble; the members and weights depend on the
artifact kind. Each member is normalised to 0-100, then combined by weight.
Dropping a member (`--disable`) re-normalises across the remaining weights.

- **skill** → `skill-tools` (40), `skill-validator` (30), `claudelint` (30)
- **agent** → `claudelint` (50), `agnix` (30), `cclint` (20)

`skillcheck` and `skillspector` are the security scanners (not part of the
quality ensemble); they drive the security dimension and the score cap.

## The four dimensions and the overall score

`audit.Run` fuses four dimensions into one 0-100 overall score
(`internal/audit/score`):

```text
overall = round(0.35*quality + 0.35*reliability + 0.20*security + 0.10*impact)
```

- **quality (35%)** — the weighted linter ensemble above.
- **reliability (35%)** — a deterministic structural gate (frontmatter +
  structure), floored by the claudelint conformance score.
- **security (20%)** — the highest severity across `skillcheck` and
  `skillspector`. The highest finding also **caps** the overall score:
  `HIGH` caps at 75, `CRITICAL` caps at 50.
- **impact (10%)** — a behavioral signal. The `flox-ai audit` CLI does not
  expose the behavioral eval, so impact is always **estimated at 70**.

The capped overall maps to a status pill: `stable` (≥80), `warn` (≥60),
`risk` (<60).

## Fail-closed behavior

If a tool is missing, crashes, or emits output that fails to parse, that
member scores **0** and is flagged in the `quality.checks` breakdown rather
than read as a clean pass. A broken tool can only lower a score, never inflate
it. (This is why a fresh environment with no tools installed shows every skill
at `quality 0` until the tools are installed — see the review flow in
[tui.md](tui.md).)

## Dry-run

`REVIEW_SKILLS_DRY_RUN=1` makes every tool adapter return a fixed stub score
without invoking the real CLI. The e2e tests use it so they need no tools on
PATH ([development/testing.md](../development/testing.md)).
