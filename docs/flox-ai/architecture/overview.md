# Package overview

flox-ai is one Go module, `flox.dev/flox-ai`, in
`.flox/pkgs/flox-ai`. `main.go` is the CLI entry; everything else is
under `internal/`.

## Commands

`main.go` parses a subcommand and dispatches:

| Command | Purpose |
| ------------------------------ | ------- |
| `setup-hook` / `setup-profile[-bash/-zsh/-fish]` | Emit shell code that wires the environment (PATH, `CLAUDE_CONFIG_DIR`, fragment symlinks) |
| `rules` / `skills` / `agents` / `plugins` `add|remove|list|clean` | Manage fragment symlinks (and plugin JSON) |
| `doctor` | Validate fragment frontmatter and report audit-tool availability |
| `audit <path>` | Score a skill/agent in-process (`--json --findings --report --threshold --kind`) |
| `launch <agent> [-- args]` | Run an agent (claude / agent-deck) with fragments injected |
| `tui` | The Bubble Tea browser (requires a Flox environment) |
| `version` | Print the semver |

## Internal packages

| Package | Responsibility |
| ------------------------- | -------------- |
| `internal/discover` | Scan `share/claude-code` for rules/skills/agents/plugins |
| `internal/symlinks` | Create/clean the managed fragment symlinks |
| `internal/plugins` | Plugin symlinks plus `installed_plugins.json` / `known_marketplaces.json` |
| `internal/emit` | Generate the activation hook and profile shell code |
| `internal/doctor` | Fragment frontmatter validation (`Check`) plus tool availability (`Probe`/`Resolve`) — see [ADR 0004](../decisions/0004-unify-doctor.md) |
| `internal/launch` | Agent registry and dispatch: claude (exec) and agent-deck (`RunDeck`) |
| `internal/manifest` | Read the environment's installed set from the lockfile |
| `internal/catalog` | The embedded fragment catalog (built from website data) |
| `internal/tui` | The Bubble Tea UI — see [tui.md](tui.md) |
| `internal/audit` | The in-process scoring engine — see [audit-engine.md](audit-engine.md) |

## The audit sub-tree

The engine is a cluster of small packages under `internal/audit`,
absorbed from the former `review-skills` module ([ADR 0003](
../decisions/0003-absorb-audit-engine-in-process.md)):

| Package | Responsibility |
| ----------------------------- | -------------- |
| `internal/audit/audit` | Orchestrates a run; fuses the four dimensions into a 0-100 score (`Run`, `Result`, `RunOptions`) |
| `internal/audit/detect` | Detect artifact kind (skill vs agent) |
| `internal/audit/tools` | The external tool registry, per-kind ensemble, and availability probe |
| `internal/audit/score` | Scoring math (weighted ensemble, severity caps, pill/status) |
| `internal/audit/findings` | The `Finding` shape and sorting |
| `internal/audit/report` | Raw per-tool output capture |

## Dependencies

The module depends on the Charm v2 stack (`charm.land/bubbletea`,
`bubbles`, `lipgloss`), `bubblezone/v2`, `bubbletint/v2`,
`charmbracelet/x/ansi`, `pelletier/go-toml/v2` (agent-deck config), and
`gopkg.in/yaml.v3`. The build is `buildGoModule` with a pinned
`vendorHash` (see [development/build.md](../development/build.md)).
