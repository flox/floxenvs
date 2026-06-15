# gstack

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Fgstack%2Fdevcontainer.json)

Ready-to-use environment for [gstack][upstream] —
Garry Tan's Claude Code stack of 45 opinionated skills
covering planning, design, QA, code review, security,
and shipping. Layered on top of `flox/claude` so the
skills get discovered through the managed config.

[upstream]: https://github.com/garrytan/gstack

## Quick start

Include in your manifest:

```toml
[include]
environments = ["flox/gstack"]
```

Then `flox activate` and start invoking gstack skills
from Claude Code (`/qa`, `/review`, `/ship`,
`/office-hours`, …).

## What it provides

Everything from [`claude`](../claude/) plus the
`claude-code-plugin-gstack` package, which installs the
gstack plugin tree at
`$FLOX_ENV/share/claude-code/plugins/gstack/`.

`flox-ai` discovers the plugin and symlinks it
into the project-local `$CLAUDE_CONFIG_DIR/plugins/`,
so all 45 skills become available without touching
`~/.claude/`.

### Bundled runtime tools

Several gstack skills shell out to `bun`, `node`,
`git`, `jq`, and `curl`. These are bundled inside the
plugin tree at `plugins/gstack/tools/bin/` and resolved
via `${CLAUDE_PLUGIN_ROOT}` — no need for the consumer
flox env to install them separately for skills to run.

### Skills

- Planning: `/office-hours`, `/plan-ceo-review`,
  `/plan-eng-review`, `/plan-design-review`,
  `/plan-devex-review`, `/plan-tune`, `/autoplan`
- Design: `/design-consultation`, `/design-html`,
  `/design-shotgun`, `/design-review`
- Review: `/review`, `/devex-review`, `/cso` (security)
- QA: `/qa`, `/qa-only`, `/careful`, `/guard`,
  `/freeze`, `/unfreeze`
- Shipping: `/ship`, `/land-and-deploy`, `/canary`,
  `/document-release`, `/document-generate`
- Debugging & ops: `/investigate`, `/retro`,
  `/health`, `/learn`, `/benchmark`,
  `/benchmark-models`
- Browser & docs: `/browse`, `/open-gstack-browser`,
  `/setup-browser-cookies`, `/make-pdf`, `/scrape`
- Context: `/context-save`, `/context-restore`,
  `/pair-agent`, `/codex`, `/landing-report`
- Maintenance: `/gstack-upgrade`, `/skillify`,
  `/setup-deploy`, `/setup-gbrain`, `/sync-gbrain`

Full list and per-skill docs live under
`plugins/gstack/skills/<name>/SKILL.md`.

## Caveats

### Compiled CLIs (`browse`, `design`, `make-pdf`)

gstack's `/browse`, `/design-*`, and `/make-pdf` skills
shell out to bun-compiled binaries that upstream
produces with `bun install && bun run build`. We don't
run that at Nix build time (it pulls Playwright,
Puppeteer, and other JS deps from the network into a
read-only nix store path).

If you want those skills to work, run inside an
activated environment, once, in a writable copy:

```bash
cp -R "$FLOX_ENV/share/claude-code/plugins/gstack" /tmp/gstack-build
cd /tmp/gstack-build
"$FLOX_ENV/share/claude-code/plugins/gstack/tools/bin/bun" install
"$FLOX_ENV/share/claude-code/plugins/gstack/tools/bin/bun" run build
```

…then point gstack at the build directory via
`CLAUDE_PLUGIN_ROOT`. The text-only skills (everything
else) work without the build step.

### Telemetry, state, learnings

gstack writes session/telemetry/learnings state under
`$HOME/.gstack/` by default (or `$CLAUDE_PLUGIN_DATA`
if Claude Code exports it). The plugin tree itself is
read-only — `gstack-config` writes go to the state
dir, not into the nix store.

### Standalone gstack install

If you already have gstack cloned at
`~/.claude/skills/gstack/` (the upstream-recommended
install), the plugin install is independent and
non-conflicting — `flox-ai` only touches its
own config dir. Both can coexist, though Claude Code
may surface duplicate skill names.

## See also

- [gstack-demo](../gstack-demo/) — interactive demo
- Upstream: <https://github.com/garrytan/gstack>
