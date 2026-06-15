# firecrawl-demo

<!-- codespaces-badge -->
[![Open in Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/flox/floxenvs?devcontainer_path=.devcontainer%2Ffirecrawl-demo%2Fdevcontainer.json)

Interactive walkthrough for the `flox/firecrawl`
environment. On first activation it prompts for your
Firecrawl API key, saves it to the env cache, and prints
quick-start commands.

## Quick start

```bash
flox activate -r flox/firecrawl-demo
```

On activation you'll be asked for a Firecrawl API key.
Get one (free tier available) at
<https://firecrawl.dev/app/api-keys>. The key is stored
in `$FLOX_ENV_CACHE/firecrawl/api-key` and reused on
later activations, so you're only prompted once.

## Three things to try

1. Check auth and remaining credits:

   ```bash
   firecrawl --status
   ```

2. Scrape a page to clean, LLM-ready markdown:

   ```bash
   firecrawl scrape "https://firecrawl.dev" -o page.md
   ```

3. Search the web from the shell:

   ```bash
   firecrawl search "flox dev environments"
   ```

Run `firecrawl --help` or `firecrawl <command> --help`
for the full option set.

## Driving it from an agent

The bundled skill lets Claude Code or OpenCode call
`firecrawl` for you — just ask it to "search the web for
…" or "scrape this page …" and it picks the right
command. The skill files come from the included
`flox/firecrawl` environment.

## See also

For the minimal environment without the prompt or banner,
see [firecrawl](../firecrawl/).
