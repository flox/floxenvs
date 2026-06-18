# 0011. Inject codex fragments via a downstream env-var patch

Date: 2026-06-18

Status: Accepted

## Context

Adding codex as a launchable agent meant injecting this environment's
skills and rules into it. Unlike Claude Code, codex exposes none of the
injection flags flox-ai relies on (`--plugin-dir`,
`--append-system-prompt-file`). Researched against codex-cli 0.140.0:

- **Skills** use the identical `SKILL.md` format, but discovery is
  location-fixed: codex scans `.agents/skills/` (cwd up to repo root) or
  `$HOME/.agents/skills`. It follows symlinked skill folders.
- **Rules** map to project docs: codex reads `AGENTS.override.md` →
  `AGENTS.md` → fallbacks, one file per directory, with a global
  `~/.codex/AGENTS.md`.
- `--add-dir` only grants sandbox write access; it does not trigger
  skill or rule discovery.
- There is no documented `-c` config knob or env var for an arbitrary
  extra skill root. Discovery is location-fixed, not pointer-based.

Pointing codex at the read-only Nix store is therefore impossible
without either polluting the project working tree (`.agents/skills/`,
`AGENTS.md` — which also clobbers an existing repo `AGENTS.md`) or
relocating `CODEX_HOME` (heavy, takes over the user's whole codex
state). Both are ugly.

codex is Apache-2.0 and flox already builds it from source
(`rustPlatform.buildRustPackage`, `fetchFromGitHub` tag
`rust-v${version}`, `sourceRoot = source/codex-rs`). Source inspection
found clean seams: `core-skills/src/loader.rs::skill_roots()` already
threads an `extra_skill_roots` parameter, and
`core/src/agents_md.rs::load_project_instructions()` has an append point
for an extra instruction entry.

## Decision

We will carry a small downstream patch,
`.flox/pkgs/codex/flox-fragments.patch`, that adds two env-var seams (a
leaf-function read each, ~5 lines):

- `CODEX_FLOX_SKILL_ROOTS` — colon-separated absolute paths, appended as
  user-scope skill roots in `loader.rs`.
- `CODEX_FLOX_INSTRUCTIONS_FILE` — a file path read and appended as an
  internal-provenance instruction entry in `agents_md.rs`.

An env var (not a CLI flag or config key) is deliberate: it is a
localized leaf read that survives version bumps, whereas a flag would
thread through the clap arg structs and config crate. `default.nix`
applies the patch via `patches = [ ./flox-fragments.patch ]`;
`upgrade.sh` warns the patch must be re-verified on every codex bump.

`RunCodex` (`internal/launch/codex.go`) stages a skill root and a merged
rules file under `$FLOX_ENV_PROJECT/.flox/cache/flox-ai/codex/`, sets the
two env vars plus `FLOX_AI=1`, and execs codex. Standalone agents are
wrapped as `<name>/SKILL.md` so codex surfaces them as skills.
Claude-format plugins are not mapped — codex's plugin format
(`.codex-plugin/` + marketplace.json) is incompatible.

## Consequences

- `+` Injects environment-managed skills/agents/rules without mutating
  `~/.codex`, without working-tree pollution, and without `CODEX_HOME`
  relocation.
- `+` The patch touches no Cargo dependencies, so the pinned `hash` and
  `cargoHash` stay valid across the patch.
- `+` Env-var seams are tiny and localized, easing re-verification.
- `-` A downstream patch must be re-verified on every codex version bump
  (it targets `core-skills/src/loader.rs` and `core/src/agents_md.rs`);
  building codex from source is slow (Rust + V8).
- `-` Claude-format plugins are not injected into codex.
- `-` The agents-to-skills mapping is naive (each agent `.md` wrapped as
  `<name>/SKILL.md`); codex's real subagents concept differs.
- `-` A skill and an agent sharing a name collide in the staged skill
  root (symlink error); not yet handled.
- `-` Only build success and env-var string presence in the binary were
  verified; a live codex session reading the roots was not run (needs
  auth/network).

Build/dev gotchas worth carrying forward: nix copies only git-tracked
files, so a new patch or source file must be `git add`ed before
`flox build codex`; the build artifact is `./result-codex` (named per
package), gitignored via `/result-*`.

---

Supersedes the codex portion of the proposed
[0010](0010-per-agent-fragment-injection.md) by landing the patch
approach concretely. The broader per-agent adapter refactor in 0010
remains proposed and will migrate `RunCodex` onto the `Adapter`
interface.
