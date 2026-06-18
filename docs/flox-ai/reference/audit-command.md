# `flox-ai audit`

Score a single skill or agent on a 0-100 scale, in-process. The command
backs the same engine the TUI's review report uses, so a score from the CLI
and from the TUI agree.

This consolidates what the former `review-skills` binary split across
`audit` / `review` / `lint` / `report` ([ADR 0005](
../decisions/0005-single-audit-command.md)). What the score means and which
tools run is in [audit-tools.md](../architecture/audit-tools.md).

## Usage

```text
flox-ai audit <path> [--json] [--findings] [--report]
                     [--threshold N] [--kind skill|agent]
                     [--tools <list>] [--disable <list>]
```

`<path>` is a skill directory (containing `SKILL.md`) or an agent `.md` file;
the kind is auto-detected unless `--kind` is given. Flags may appear on either
side of the path.

## Flags

| Flag | Effect |
| ------------------ | ------ |
| `--json` | Emit the machine-readable `Result` document instead of the human summary. |
| `--findings` | Include the normalised findings array (`tool`, `severity`, `rule`, `message`, `file`, `line`), fused and sorted across all tools. |
| `--report` | Append each tool's raw stdout under `=== <tool> ===` headers (implies findings + raw capture). |
| `--threshold N` | Exit non-zero when the overall score is below `N`. The CI gate. |
| `--kind skill\|agent` | Override artifact detection. |
| `--tools <list>` | Restrict the quality ensemble to exactly these tools (comma-separated). |
| `--disable <list>` | Drop these tools from the quality ensemble; remaining weights re-normalise. |

`--tools` and `--disable` are mutually exclusive in intent (use one).

## Output

Default (human) output is a summary line plus per-dimension scores and the
quality checks:

```text
skill  my-skill  overall 75 (warn)
  quality 83  reliability 95  security 80  impact 70
    skill-tools      w40  pass  75
    skill-validator  w30  pass  80
    claudelint       w30  pass  95
```

`--json` emits the full `Result`:

```json
{
  "identity": { "kind": "skill", "name": "my-skill", "dir": "…" },
  "overall": 75,
  "status": "warn",
  "quality":     { "score": 83, "checks": [ { "id": "skill-tools", "weight": 40, "note": "75", "pass": true } ] },
  "reliability": { "score": 95 },
  "security":    { "score": 80, "cap": 75, "severity": "HIGH" },
  "impact":      { "score": 70, "estimated": true },
  "findings":  [ { "tool": "skill-validator", "severity": "warning", "rule": "Structure", "message": "unexpected file at root: Dockerfile", "file": "Dockerfile" } ],
  "rawByTool": { "skill-validator": "…" }
}
```

`findings` appears with `--findings`/`--report`; `rawByTool` with `--report`.

## Exit codes

| Code | Meaning |
| ---- | ------- |
| `0` | Scored (and, with `--threshold`, met it). |
| `1` | Usage error, a hard failure, or overall score below `--threshold`. |
| `2` | Flag parse error. |

## Examples

```bash
# Human summary, kind auto-detected
flox-ai audit ./skills/my-skill

# JSON with findings
flox-ai audit ./skills/my-skill --json --findings

# Everything, including raw tool output
flox-ai audit ./agents/my-agent.md --kind agent --report

# CI gate: fail the build under 70
flox-ai audit ./skills/my-skill --threshold 70

# Score with only two quality tools
flox-ai audit ./skills/my-skill --tools skill-tools,claudelint
```

## Prerequisites

Real scores need the six quality tools on PATH; run `flox-ai doctor` to see
which are present, and install any missing `flox/<tool>` packages. For offline
or test use, `REVIEW_SKILLS_DRY_RUN=1` returns deterministic stub scores
without invoking any tool.
