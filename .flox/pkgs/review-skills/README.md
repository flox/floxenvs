# review-skills

A self-contained Go CLI that computes a unified 0-100
quality score for Claude Code skills and agents. It detects
whether a path is a skill (`SKILL.md`) or an agent (`.md`
with agent frontmatter), runs a per-kind ensemble of
linters, normalizes each tool to 0-100, and fuses the
results into four dimensions plus a security cap and a status
pill.

The binary shells out to six scoring tools by bare name
(`skill-tools`, `skill-validator`, `claudelint`, `cclint`,
`agnix`, `skillcheck`, `skillspector`) and, optionally, `promptfoo`. Those
tools are provided by the `review-skills` Flox environment;
this package is only the runner.

## Commands

```bash
review-skills audit  <path>   # full 0-100 metrics
review-skills review <path>   # quality score only
review-skills lint   <path>   # deterministic gate, exit 0/1
review-skills report <path>   # raw per-tool output
review-skills doctor          # tool availability + smoke + ensemble
review-skills version         # print the semver
```

### audit

Runs the full pipeline and prints either a one-liner
(`<kind> <name>: <overall> (<status>)`) or, with `--json`,
the complete `metrics.json` (identity / overall / status /
quality / reliability / security / impact).

Flags:

- `--json` — emit machine-readable JSON.
- `--kind skill|agent` — override artifact detection.
- `--threshold <n>` — exit nonzero if the overall score is
  below `<n>`.
- `--findings` — include a normalized findings array
  (`severity` / `tool` / `rule` / `message` / `file` /
  `line`) fused and sorted across every tool.
- `--tools <list>` — restrict the quality ensemble to
  exactly the named tools (comma-separated).
- `--disable <list>` — drop the named tools from the quality
  ensemble; remaining weights re-normalize automatically.
- `--with-behavioral` — run a `promptfoo` behavioral eval for
  the impact dimension (needs an LLM provider API key).

`--tools` and `--disable` are mutually exclusive.

### review

Quality dimension only. Supports `--json`, `--kind`,
`--threshold` (gates on the quality score), `--tools`, and
`--disable`.

### lint

Runs only the deterministic structural gate and exits 0
(pass) or 1 (fail). Supports `--kind`.

### report

Runs the selected tools and prints each tool's raw output
under grouped headers, or `--json` for
`[{tool, raw}]`. Supports `--kind`, `--tools`, `--disable`.

### doctor

Probes every tool in the registry: availability
(`ok` / `not-found` / `broken`), version, and a smoke test
against an embedded fixture, then prints the resolved
per-kind ensemble. Exits nonzero if a default-ensemble tool
is missing or broken. Supports `--kind`.

## The four dimensions

`audit` fuses the ensemble into one overall score:

- **quality (35%)** — weighted ensemble of the linters for
  the artifact kind (skills: skill-tools 40 / skill-validator
  30 / claudelint 30; agents: claudelint 50 / agnix 30 /
  cclint 20). Each tool is normalized to 0-100; dropping a
  tool re-normalizes via the remaining weights.
- **reliability (35%)** — the deterministic gate
  (frontmatter + structure), floored by claudelint
  conformance.
- **security (20%)** — `skillcheck` + `skillspector` SARIF severity (the highest across both scanners). The
  highest finding also caps the overall score: HIGH caps at
  75, CRITICAL caps at 50.
- **impact (10%)** — behavioral signal. Estimated at 70
  unless `--with-behavioral` runs a real promptfoo eval.

The overall score maps to a status pill: `stable` (>=80),
`warn` (>=60), `risk` (<60).

## Fail-closed behavior

If any underlying tool is missing or crashes, or emits
output that fails to parse, that member scores 0 and is
flagged in the `quality.checks` breakdown rather than being
read as a clean pass. A broken tool can only lower a score,
never inflate it.

## Environment variables

- `REVIEW_SKILLS_QUICK_VALIDATE` — path to the
  `quick_validate.py` used by the skill gate. If unset (or
  PyYAML is unavailable) the runner falls back to a
  dependency-free inline frontmatter check.
- `REVIEW_SKILLS_DRY_RUN=1` — make every tool adapter return
  a fixed stub score instead of invoking the real CLI (used
  by the package's own tests and e2e fixtures).

## Development

```bash
# Fast unit tests during dev
cd .flox/pkgs/review-skills && go test ./...

# Build the binary (Go tests run in the check phase)
flox build review-skills
# -> ./result-review-skills/bin/review-skills

# bats e2e
nix run .#run-test-review-skills-with-nix
```

The module is laid out as `main.go` (flag dispatch) plus
`internal/{detect,score,findings,tools,audit,doctor,report}`.
The tool registry in `internal/tools` encapsulates every
per-tool quirk; the orchestrator in `internal/audit` runs the
selected tools, scores via the ported ensemble, and fuses
into `metrics.json`.
