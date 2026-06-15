# flox-ai

A small Go binary that assembles Claude Code configuration
from Flox package fragments and emits eval-able shell code.
Depends only on `gopkg.in/yaml.v3` for frontmatter parsing.

## Usage

```toml
# manifest.toml
[hook]
on-activate = '''
eval "$(flox-ai setup-hook)"
'''

[profile]
common = '''
eval "$(flox-ai setup-profile)"
'''
```

The setup is split into two phases because of how flox
hooks work:

- **`on-activate`** runs in a context where only env vars
  persist to the user's shell. Filesystem side effects
  (mkdir, cp, symlinks) persist, but function definitions
  and traps do not.
- **`[profile]`** runs in the user's actual shell, so
  function definitions and EXIT traps survive for the
  lifetime of the session.

## Commands

```bash
flox-ai setup-hook      # env vars, keychain, symlinks
flox-ai setup-profile   # cleanup function + EXIT trap
flox-ai doctor          # config status, symlink health, validation
flox-ai rules add       # install a rule (symlink)
flox-ai rules remove    # remove a rule by name
flox-ai rules list      # show installed rules
flox-ai rules clean     # remove stale managed rules
flox-ai skills add      # install a skill (symlink)
flox-ai skills remove   # remove a skill by name
flox-ai skills list     # show installed skills
flox-ai skills clean    # remove stale managed skills
flox-ai agents add      # install an agent (symlink)
flox-ai agents remove   # remove an agent by name
flox-ai agents list     # show installed agents
flox-ai agents clean    # remove stale managed agents
flox-ai plugins add     # install plugin
flox-ai plugins remove  # remove plugin by name
flox-ai plugins list    # show installed plugins
flox-ai plugins clean   # remove stale plugins
flox-ai version         # print version
```

### setup-hook

Emits shell code for the on-activate hook phase:

1. Exports env vars (`CLAUDE_CONFIG_DIR`, etc.)
2. Bridges macOS Keychain credentials for the isolated
   config dir
3. Copies `~/.claude.json` for OAuth account metadata
4. Cleans stale symlinks and creates fresh ones in
   `$CLAUDE_CONFIG_DIR/{rules,skills,agents}/`

The hook does not validate fragments: surfacing frontmatter
warnings on every activation is noisy. Run `flox-ai doctor`
to see frontmatter and structure validation on demand.

### setup-profile

Emits shell code for the profile phase:

1. Defines the `_flox_ai_clean_symlinks` helper
2. Defines the `_flox_ai_cleanup` function
3. Registers `trap _flox_ai_cleanup EXIT`

### doctor

Single diagnostic view combining:

- Config dir + activation marker
- Auth bridge status
- Per-fragment symlink health (`✓` installed, `→ broken`
  if the link target is missing, `·` available but not
  installed)
- Frontmatter and structure validation, with errors
  (broken) and warnings (unusual but works) reported
  inline per fragment

Exits non-zero only on errors.

**Rules** (`rules/*.md`):

- File is readable (error if not)
- Unknown frontmatter keys produce a warning
  (only `paths` is recognized)

**Skills** (`skills/*/SKILL.md`):

- SKILL.md exists and is readable (error if not)
- If frontmatter is present, `name` and `description`
  are required (error if missing)
- `name` is kebab-case, ≤64 characters (error)
- `description` ≤1024 characters (warning if exceeded)
- `compatibility` ≤500 characters (warning if exceeded)
- `effort` is one of: low, medium, high, max (error)
- Frontmatter keys are recognized as either
  agentskills.io spec keys or Claude Code extensions
  (warning otherwise; the `metadata:` mapping is the
  spec-recommended home for non-standard fields)

**Agents** (`agents/*.md`):

- File is readable (error if not)
- No forbidden keys (`hooks`, `mcpServers`,
  `permissionMode` — security restriction, error)
- `effort` is one of: low, medium, high, max (error)
- `isolation` is `worktree` (only valid value, error)
- Unknown frontmatter keys produce a warning

### rules/skills/agents add

Installs a rule, skill, or agent by creating a
relative symlink in `$CLAUDE_CONFIG_DIR/<type>/<name>`.

### rules/skills/agents remove

Removes the symlink by name.

### rules/skills/agents list

Shows entries in `$CLAUDE_CONFIG_DIR/<type>/` with
symlink health status.

### rules/skills/agents clean

Removes symlinks whose targets point into
`$FLOX_ENV/share/claude-code/<type>/`. User-created
symlinks are preserved.

### plugins add

Installs a plugin by creating a symlink in
`$CLAUDE_CONFIG_DIR/plugins/` and merging the
plugin's `installed_plugins.json` and
`known_marketplaces.json` into the config dir's
accumulated files.

### plugins remove

Removes a plugin symlink by name and regenerates
the JSON config files from remaining plugins.

### plugins list

Shows all installed plugins in the config dir with
symlink health status.

### plugins clean

Removes all plugin symlinks whose targets point
into `$FLOX_ENV/share/claude-code/`. Regenerates JSON
config files from remaining plugins. User-managed
plugins are never touched.

Rules, skills, and agents `clean` works identically
but without JSON regeneration.

## How it works

Flox packages drop config fragments into
`$FLOX_ENV/share/claude-code/`. On `flox activate`:

The Go binary handles discovery and validation.
Everything else (symlinks, keychain, cleanup) is emitted
as shell code — visible and debuggable.

### Why two phases?

Flox `on-activate` hooks run in a subshell-like context.
Env var exports and filesystem side effects persist, but
shell function definitions and `trap` registrations do not
survive to the user's interactive shell. An EXIT trap
registered in `on-activate` fires immediately when the
hook context exits — deleting files that were just created.

The `[profile]` section runs in the user's actual shell,
so functions and traps defined there persist for the
session.

### Fragment types

Packages install fragments under
`$FLOX_ENV/share/claude-code/`:

| Directory | Format | Delivery |
| ------ | ------ | ------ |
| `rules/*.md` | Rule files | Symlink |
| `skills/*/SKILL.md` | Skill directories | Symlink |
| `agents/*.md` | Agent files | Symlink |
| `plugins/*/` | Plugin directories | Symlink + JSON |
| | | merge |

All fragment types are delivered via symlinks into
`$CLAUDE_CONFIG_DIR/`.

### Isolation via CLAUDE_CONFIG_DIR

`CLAUDE_CONFIG_DIR` is set to
`$FLOX_ENV_PROJECT/.flox-ai`, a directory next to
the project's `.claude/`. This isolates the Claude session:

- No user settings from `~/.claude/` leaking in
- No user `CLAUDE.md` leaking in
- No user memory files leaking in
- Session transcripts stay in the managed dir
- Auto-memory disabled via
  `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`

## Authentication

Claude Code stores OAuth credentials in the macOS Keychain
(or platform equivalent). The service name is derived from
`CLAUDE_CONFIG_DIR`:

- Default (no env var): `Claude Code-credentials`
- With custom dir: `Claude Code-credentials-<sha256[:8]>`

Since we set `CLAUDE_CONFIG_DIR` for isolation, Claude
looks for credentials under a hashed service name that
doesn't exist yet. The emitted shell code bridges this gap
automatically.

### How the keychain bridge works

At activate time, the `setup-hook` shell code:

1. Computes the SHA-256 hash of `$CLAUDE_CONFIG_DIR`
   (first 8 hex chars) to derive the isolated service name
2. Checks if the isolated keychain entry already exists
   (idempotent — skips if present)
3. Reads the default entry (`Claude Code-credentials`) via
   `security find-generic-password -w` (returns plaintext)
4. Re-encodes the plaintext with `xxd -p` (hex) and writes
   it under the isolated service name using
   `security add-generic-password -X`
5. Copies `~/.claude.json` into `$CLAUDE_CONFIG_DIR/` for
   `oauthAccount` metadata

All `security` commands use `|| true` to guard against
`set -e` in flox hooks.

### Token refresh

OAuth tokens expire after ~1 hour with a ~5-minute refresh
buffer. When Claude refreshes a token, it writes back to
the same service name it read from — the isolated one.
This is self-consistent: the bridge is only needed once at
activate time.

### Cleanup

The EXIT trap (registered in `setup-profile`) removes the
bridged keychain entry and the copied `.claude.json` when
the shell exits. Each new `flox activate` creates a fresh
bridge.

### Linux

On Linux, Claude Code uses a file-based credential store
at `$CLAUDE_CONFIG_DIR/.credentials.json`. No bridging is
needed since Claude creates and manages this file directly
in the isolated config dir.

### Symlink lifecycle

The `setup-profile` shell defines a
`_flox_ai_clean_symlinks` helper that removes
symlinks whose targets point into
`$FLOX_ENV/share/claude-code/`. User-created entries are never
touched.

**On activate:** `setup-hook` cleans stale symlinks, then
`ln -sfn` creates fresh ones.

**On exit (trap):** cleanup function runs the helper
again, removing all managed symlinks.

## Environment variables

### Read by flox-ai

| Variable | Purpose |
| ------ | ------ |
| `FLOX_ENV` | Flox environment path (fragment source) |
| `FLOX_ENV_PROJECT` | Project root (for relative paths) |
| `FLOX_AI_DIR` | Override config dir location |
| `FLOX_AI` | Check if managed mode is active |

If `FLOX_AI_DIR` is not set, defaults to
`$FLOX_ENV_PROJECT/.flox-ai`.

### Set by emitted shell code

| Variable | Purpose |
| ------ | ------ |
| `CLAUDE_CONFIG_DIR` | `$FLOX_ENV_PROJECT/.flox-ai` |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY` | Disables memory |
| `FLOX_AI` | Marker that managed mode is active |

## Architecture

```text
main.go                     CLI entry point, env var
                            resolution, command dispatch
internal/
  discover/                 Scan $FLOX_ENV/share/claude-code/
  emit/                     Generate shell code
                            hook: env vars, keychain,
                                  symlinks
                            profile: cleanup function,
                                     trap
  doctor/                   Fragment validation
                            (frontmatter, structure)
  symlinks/                 Shared symlink operations
                            (Add, Remove, List, Clean)
  plugins/                  JSON merge, add/remove/list/
                            clean
e2e/                        Bats E2E test suite
  test_helper/common.bash   Shared helpers, mode detection
  fixtures/                 Static test fragments
```

## Building

```bash
flox build flox-ai
```

### Updating dependencies

Bumping or adding a Go dependency requires regenerating
the `vendorHash` in `default.nix`:

1. Edit `go.mod` (e.g. `go get example.com/pkg@vX.Y.Z`)
2. Run `go mod tidy` to refresh `go.sum`
3. Set `vendorHash` to a placeholder
   (`sha256-AAAA...AAA=`) and run `nix-build`
4. Copy the `got: sha256-...` line from the failure into
   `vendorHash` and rebuild

Tests cover the parser and validators. Re-run
`go test ./...` after touching `internal/doctor/`.

## Testing

### Unit tests (Go)

```bash
cd .flox/pkgs/flox-ai
go test ./...
```

### E2E tests

70 bats tests covering command output, shell eval,
validation, security edge cases, and cleanup safety.
Two runners are available from the repo root:

**Hermetic (no flox required):**

```bash
nix run .#run-test-flox-ai-with-nix
```

Builds the binary via Nix, sets `flox-ai` on
PATH, runs bats against temp fixture trees using
`--dir` and `--config-dir` flags. No `FLOX_*`
variables are set.

**With flox (real lifecycle):**

```bash
nix run .#run-test-flox-ai-with-flox
```

Creates a throwaway flox environment, installs the
built binary via `on-activate`, and runs the same bats
tests inside `flox activate`. Tests `FLOX_ENV` and
`FLOX_ENV_PROJECT` integration.

### Test structure

```text
e2e/
  test_helper/
    common.bash          mode detection, fixture helpers
  version.bats           version command
  setup-hook.bats        setup-hook output
  setup-profile.bats     setup-profile output
  doctor.bats            diagnostics: status + validation
  eval-hook.bats         eval shell output, side effects
  eval-profile.bats      eval profile, cleanup
  edge-cases.bats        robustness + security
  fixtures/              static test fragments
```

`common.bash` detects the execution mode via `FLOX_ENV`
and adapts flag usage. Both runners execute the same
bats files.
