# 0010. Inject fragments per-agent via each agent's native seam

Date: 2026-06-18

Status: Proposed

## Context

`flox-ai launch <agent>` injects flox-managed fragments (skills, rules,
agents, plugins) into a child agent process without mutating the user's
shell or global config. The claude path already does this: it builds a
synthesized Claude Code plugin under a writable cache
(`$FLOX_ENV_PROJECT/.flox/cache/flox-ai/launch`), symlinks skills and
agents into it, merges rules into one file, then execs claude with
`--plugin-dir` and `--append-system-prompt-file`.

The fragment source lives in the read-only Nix store
(`$FLOX_ENV/share/claude-code/`, reached via `.flox/run/…` →
`/nix/store/…`, mode `0555`). So a fragment dir cannot be handed to an
agent as-is when the agent needs a manifest or a writable layout next
to it.

We considered shipping each skill package pre-built per agent
(`share/<agent>/<plugin>`) so launch could point an agent at a
read-only dir with no synth step. Whether that works depends entirely
on how each target agent discovers and consumes fragments. We need to
support four agents — claude, codex, opencode, pi — so we researched
each one's discovery mechanism from source.

Findings (authoritative, from each agent's source):

| agent | skills seam | rules seam | plugin/local | symlink-follow | injection without clobber |
| ------ | ------------------------------ | ----------------------------------- | ------------------------- | -------------- | --------------------------------------- |
| claude | `--plugin-dir` (plugin layout) | `--append-system-prompt-file` | `--plugin-dir` (direct) | yes | CLI flags (session-only) |
| codex | `.agents/skills/` fixed dirs | `AGENTS.md` chain (one file per dir) | own `.codex-plugin` format | yes | none — discovery is location-fixed |
| opencode | `config.skills.paths[]` | `config.instructions[]` | `config.plugin[]` (local paths) | yes | `OPENCODE_CONFIG_CONTENT` (merged config) |
| pi | `--skill <path>` (file/dir) | `--append-system-prompt <file>` | `-e <ext>` (different model) | n/a (real dirs) | CLI flags (session-only) |

Key consequences of the findings:

- **SKILL.md is universal.** All four consume the identical `SKILL.md`
  format. One synthesized skills tree can feed all four; only the
  pointing mechanism differs.
- **Three of four expose a read-in-place or merge seam.** claude
  (`--plugin-dir`), opencode (`skills.paths` + merged
  `OPENCODE_CONFIG_CONTENT`), and pi (`--skill`) can all be pointed at a
  dir and read it without writing into it or clobbering user config.
  opencode merges configs (set-union on `instructions`/`skills.paths`),
  so injection never overwrites the user's `opencode.json`. pi flags are
  session-scoped.
- **codex is the exception.** Its discovery is location-fixed
  (`.agents/skills/` walked from cwd to repo root; one `AGENTS.md` per
  dir) with no config or env knob. Pointing at a read-only store dir is
  impossible; injecting into the working tree pollutes the repo and
  clobbers an existing `AGENTS.md`. codex is Apache-2.0 and flox builds
  it from source (`buildRustPackage`, already `substituteInPlace`s), so
  a small downstream patch is feasible: the `extra_skill_roots` param
  already threads through `skill_roots()`, and `load_project_instructions`
  has a clean append point. Two ~5-line env-var reads
  (`CODEX_FLOX_SKILL_ROOTS`, `CODEX_FLOX_INSTRUCTIONS_FILE`) add the
  missing seam without touching clap or the config crate.
- codex's own marketplace plugin format (`.codex-plugin/` +
  marketplace.json) is incompatible with Claude-format plugins and is
  out of scope.
- opencode and pi both natively read `~/.claude/CLAUDE.md` and claude
  skills, plus `AGENTS.md` — free interop, not relied on here.

## Decision

We will inject fragments through a per-agent launch adapter (`RunX`),
each using that agent's **native discovery seam**, fed from one
synthesized fragment tree in the writable flox cache:

- **claude** — synth Claude plugin + `--plugin-dir`,
  `--append-system-prompt-file` (the existing path).
- **pi** — CLI flags: `--skill <dir>` per fragment, `--append-system-prompt
  <rules.md>`. Session-scoped; no config write.
- **opencode** — set `OPENCODE_CONFIG_CONTENT` to an inline config
  (`{skills:{paths},instructions,plugin}`) pointing at the flox cache.
  Merged with the user's config, not clobbering it.
- **codex** — patch codex (`.flox/pkgs/codex/`) to read
  `CODEX_FLOX_SKILL_ROOTS` and `CODEX_FLOX_INSTRUCTIONS_FILE`; `RunCodex`
  builds the synth skill root + merged rules in cache and sets those env
  vars. No working-tree pollution, no `~/.codex` clobber, no
  `CODEX_HOME` relocation.

We will NOT ship pre-built per-agent trees (`share/<agent>/<plugin>`) in
the package. A neutral source layout (`share/claude-code/{rules,skills,
agents,plugins}`) plus a launch-time adapter avoids N copies per skill,
lets a new agent be added without repackaging every skill, and keeps the
store content read-only.

Each adapter is `(injection mechanism, launch action)`: two CLI-flag
(claude, pi), one merged-config-env (opencode), one patched-env (codex).

## Consequences

- `+` One neutral fragment source; each agent adapted at launch. Adding
  an agent is a new `RunX` + a row in `launch.Supported`, not a repackage
  of every skill.
- `+` Three of four agents need no patch and no store mutation — they
  read the cache (or store) in place; opencode merges rather than
  clobbers; pi and claude flags are session-scoped.
- `+` One synth skills tree (universal `SKILL.md`) serves all four.
- `-` codex carries a downstream source patch that must be re-verified
  on every version bump (`upgrade.sh`), and building codex from source
  is slow (Rust + V8, ~280 MB).
- `-` The launch-time synth/symlink step does not go away — it is
  required for codex and remains the simplest way to merge multi-package
  skills into one container for the others.
- `-` Standalone agents (`.md`) and Claude-format plugins map cleanly
  only to claude; codex/opencode/pi map agents fuzzily and plugins are
  largely out of scope.
- `-` Per-agent seams drift independently across upstream releases; each
  adapter is a separate maintenance surface.

---

Research basis: codex 0.140.0 (`rust-v0.140.0`); opencode 1.17.8
(`anomalyco/opencode`, config seams in `config/config.ts`,
`skill/index.ts`, `session/instruction.ts`); pi (`earendil-works/pi`,
`packages/coding-agent` `src/main.ts`, `src/config.ts`). codex patch +
`RunCodex` are in flight in a separate worktree and not yet committed;
opencode and pi adapters are research only.
