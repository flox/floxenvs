# claude-code-plugin-financial-services

Flox-packaged build of [anthropics/financial-services][upstream]
— the Claude for Financial Services marketplace, packaged as a
single FloxHub package that ships **19 Claude Code plugins**
(7 vertical bundles + 10 named agent plugins + 2 partner-built
plugins) plus the helper scripts, managed-agent cookbooks, and a
wrapped `python3` carrying every Python dependency the skills
and scripts need.

## Install

Add to a `flox/claude`-based environment:

```toml
schema-version = "1.10.0"

[include]
environments = ["flox/claude"]

[install]
financial-services.pkg-path = "claude-code-plugin-financial-services"
```

On `flox activate`, `claude-managed setup-hook` (provided by
the included `flox/claude` env) discovers all 19 plugins under
`$FLOX_ENV/share/claude-code/plugins/`, symlinks them into
`$CLAUDE_CONFIG_DIR/plugins/<name>/`, and merges every
`installed_plugins.json` so Claude Code trusts each one. The
plugins, their slash commands, hooks, and MCP wiring are
available in the next Claude Code session.

## Plugins (19)

- **financial-analysis** — Core financial modeling and analysis
  tools: DCF, comps, LBO, 3-statement models, competitive
  analysis, and deck QC
- **investment-banking** — Investment banking productivity
  tools - client and market insights, deck creation, financial
  analysis, and transaction management
- **equity-research** — Equity research tools: earnings
  analysis, initiating coverage reports, and research workflows
- **private-equity** — Private equity deal sourcing and
  workflow tools: company discovery, CRM integration, and
  founder outreach
- **wealth-management** — Wealth management and financial
  advisory tools: client reviews, financial planning, portfolio
  analysis, and client reporting
- **fund-admin** — Fund administration and finance ops: GL
  reconciliation, break tracing, accruals, roll-forwards,
  variance commentary, NAV tie-out
- **operations** — Operational workflows: KYC document parsing
  and rules-grid evaluation
- **pitch-agent** — Comps, precedents, LBO to a branded pitch
  deck, end to end
- **market-researcher** — Sector or theme to industry overview,
  competitive landscape, peer comps, and ideas shortlist
- **earnings-reviewer** — Earnings call and filings to model
  update to note draft
- **meeting-prep-agent** — Briefing pack before every client
  meeting
- **model-builder** — DCF, LBO, 3-statement, comps - live in Excel
- **gl-reconciler** — Finds breaks, traces root cause, routes
  for sign-off
- **kyc-screener** — Parses onboarding docs, runs the rules
  engine, flags gaps
- **valuation-reviewer** — Ingests GP packages, runs valuation
  template, stages LP reporting
- **month-end-closer** — Accruals, roll-forwards, variance
  commentary
- **statement-auditor** — Audits pre-generated LP statements
  before distribution
- **lseg** — Price bonds, analyze yield curves, evaluate FX
  carry trades, value options, and build macro dashboards using
  LSEG financial data and analytics.
- **spglobal** — S&P Global - Financial data and analytics
  skills including company tearsheets, earnings previews, and
  transaction summaries

## MCP servers — bring your own auth

Vertical plugins ship with `.mcp.json` files pre-wired to
**11 third-party HTTP MCP servers**:

- Daloopa — `https://mcp.daloopa.com/server/mcp`
- Morningstar — `https://mcp.morningstar.com/mcp`
- S&P Global Kensho — `https://kfinance.kensho.com/integrations/mcp`
- FactSet — `https://mcp.factset.com/mcp`
- Moody's — `https://api.moodys.com/genai-ready-data/m1/mcp`
- MT Newswires — `https://vast-mcp.blueskyapi.com/mtnewswires`
- Aiera — `https://mcp-pub.aiera.com`
- LSEG — `https://api.analytics.lseg.com/lfa/mcp` (the `lseg`
  partner plugin uses `/lfa/mcp/server-cl` instead)
- PitchBook — `https://premium.mcp.pitchbook.com/mcp`
- Chronograph — `https://ai.chronograph.pe/mcp`
- Egnyte — `https://mcp-server.egnyte.com/mcp`

Each requires a separate vendor account / authentication.
Unreachable or unauthenticated servers fail silently in
Claude Code and are skipped from `/mcp`.

## Helper scripts

Bundled at `$FLOX_ENV/share/claude-code/financial-services/scripts/`:

- `deploy-managed-agent.sh <slug>` — POST a cookbook to
  Anthropic's `/v1/agents` (Managed Agents API). Requires
  `ANTHROPIC_API_KEY`.
- `test-cookbooks.sh` — smoke-test all cookbooks in dry-run mode.
- `validate.py`, `check.py`, `orchestrate.py`,
  `sync-agent-skills.py` — skill-tooling helpers.

`python3`, `curl`, and `jq` are bundled and on PATH within the
wrapped scripts.

## Closure size

This package ships a wrapped Python with `anthropic`, `openpyxl`,
`python-pptx`, `pyyaml`, `jsonschema`, and `requests` — the
closure is ~1.7 GiB, dominated by `anthropic` SDK transitives
(`httpx`, `pydantic`) and `python-pptx`'s `lxml` + `pillow`
dependencies. This is consistent with sibling
`claude-code-plugin-claude-seo` and is the cost of "skills just
work" without separate dep provisioning.

## Upstream

- Repo: <https://github.com/anthropics/financial-services>
- License: MIT
- Pinned commit: see `hashes.json`

[upstream]: https://github.com/anthropics/financial-services
