# firecrawl

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Ffirecrawl%2Fdevcontainer.json)

Minimal Firecrawl environment. Provides the official
[Firecrawl CLI](https://github.com/firecrawl/cli)
(`firecrawl`) for scraping, crawling, searching, and
extracting web data, plus a Claude Code / OpenCode skill
bundle for driving it from an agent. It installs the
`flox-ai` launcher, which injects the bundled skills into
your assistant when you launch it.

## Quick start

Activate directly:

```bash
flox activate -r flox/firecrawl
export FIRECRAWL_API_KEY=fc-...   # from https://firecrawl.dev
firecrawl --status
firecrawl scrape "https://firecrawl.dev" -o page.md
```

## Include in your project

Add to your `manifest.toml`:

```toml
[include]
environments = [{ remote = "flox/firecrawl" }]
```

## What is included

| Package | Description |
| ------- | ----------- |
| `firecrawl-cli` | Official Firecrawl CLI (`firecrawl`) |
| `skills-firecrawl-cli` | Claude Code / OpenCode skill bundle |
| `flox-ai` | Launcher that injects skills into your assistant |

## Authentication

Firecrawl needs an API key. Get one (free tier available)
at <https://firecrawl.dev/app/api-keys>, then either:

- Export it: `export FIRECRAWL_API_KEY=fc-...`
- Or run the built-in login: `firecrawl login`

The key can also be persisted across activations by
writing it to `$FLOX_ENV_CACHE/firecrawl/api-key`; the
hook loads it automatically when `FIRECRAWL_API_KEY`
isn't already set. The [firecrawl-demo](../firecrawl-demo/)
prompts for the key interactively and saves it there.

## Configuration variables

| Variable | Default | Description |
| -------- | ------- | ----------- |
| `FIRECRAWL_API_KEY` | _(empty)_ | Firecrawl API key |
| `FIRECRAWL_DATA_DIR` | `$FLOX_ENV_CACHE/firecrawl` | State directory |

Override either in your own manifest before
`[include]`-ing this environment.

## Launching your assistant with the skills

This env does not ship Claude Code itself. First install
Claude Code (e.g. `flox install flox/claude-code`) or use
your own install, then run `flox-ai launch claude` to
start it with this environment's skills injected. The
bundled skills live under
`$FLOX_ENV/share/claude-code/skills/`; the same files are
installed for OpenCode under
`$FLOX_ENV/share/opencode/skills/`. The bundle covers
search, scrape, crawl, map, interact, parse, download,
and monitor.

## See also

For an interactive walkthrough that prompts for your API
key, see [firecrawl-demo](../firecrawl-demo/).
