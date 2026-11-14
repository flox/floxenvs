# mcporter

Flox-packaged [MCPorter](https://github.com/steipete/mcporter),
a CLI for discovering and calling Model Context Protocol
tools from your terminal.

## Install

Add MCPorter to your Flox environment:

```bash
flox install flox/mcporter
```

Activate the environment:

```bash
flox activate
```

Inside the activation, check the CLI:

```bash
mcporter --version
```

## Search the web and fetch pages

[Parallel Search MCP](https://docs.parallel.ai/integrations/mcp/search-mcp)
provides free web search and page fetching without a
Parallel account or API key. Anonymous search uses Fast
mode and has rate limits, making it suitable for exploration
and light use.

Save this as `parallel-search.json` in a scratch directory.
Use the commands below from that directory inside your
Flox activation:

```json
{
  "mcpServers": {
    "parallel-search": {
      "baseUrl": "https://search.parallel.ai/mcp",
      "headers": {
        "User-Agent": "floxenvs-mcporter"
      }
    }
  },
  "imports": []
}
```

The explicit `--config` path selects this file for each
command. Your existing MCPorter and editor configuration
files stay unchanged.

Inspect the available tools and their parameters:

```bash
mcporter --config ./parallel-search.json list parallel-search --all-parameters
```

Find current Flox documentation:

```bash
mcporter --config ./parallel-search.json call parallel-search.web_search \
  --args '{"objective":"Find Flox documentation on composing environments with include.","search_queries":["site:flox.dev/docs include environments"]}'
```

Search results include source URLs and excerpts. Fetch a
documentation page for more detail:

```bash
mcporter --config ./parallel-search.json call parallel-search.web_fetch \
  --args '{"urls":["https://flox.dev/docs/tutorials/creating-environments"]}'
```

## Links

- [MCPorter configuration](https://github.com/steipete/mcporter/blob/main/docs/config.md)
- [MCPorter call syntax](https://github.com/steipete/mcporter/blob/main/docs/call-syntax.md)
- [Parallel Search MCP setup and limits](https://docs.parallel.ai/integrations/mcp/search-mcp)
