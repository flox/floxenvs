# flox-ai documentation

`flox-ai` is the bridge between a Flox environment and AI coding agents.
It injects the rules, skills, agents, and plugins present in an
environment into Claude Code (and Agent Deck), ships a terminal UI for
browsing and installing those fragments, and audits skill/agent quality
in-process.

The docs are organised into trees by genre. Pick the one that matches
what you need; each tree has its own index.

| Tree | Start here | What it answers |
| ------------ | -------------------------------------------- | --------------- |
| Product | [product/index.md](product/index.md) | What we build and why (PRDs, goals, success metrics) |
| Architecture | [architecture/index.md](architecture/index.md) | What the system is and why (system context, components, the audit engine, the TUI) |
| Decisions | [decisions/README.md](decisions/README.md) | The significant choices and their trade-offs (ADRs) |
| Development | [development/index.md](development/index.md) | How to develop: environment, workflow, testing, build |

## What flox-ai is, in one paragraph

A single Go binary (`.flox/pkgs/flox-ai`) plus a published catalog. The
binary is installed into every AI-enabled Flox environment and wired in
through an activation hook and shell profile, so that activating an
environment makes its AI fragments available to the agent you launch.
The catalog (built from the website data) drives the TUI's browse and
install experience. As of the audit-engine merge, flox-ai also scores
skills and agents in-process — the standalone `review-skills` binary it
used to shell out to has been absorbed.

## Also in the repo

- `AGENTS.md` (repo root) — orientation for AI coding agents; routes
  into these docs and records the keep-docs-updated convention.
- `.plans/` (repo root) — the brainstorm spec and implementation plan
  the audit-engine merge was built from (not committed).
- `.flox/pkgs/flox-ai/README.md` — the package's own quick reference.

## Conventions

- **Product** is intent (what we build and why). **Architecture** is
  descriptive (what/why the system is). **Decisions** are the record of
  significant choices. **Development** is procedural (how-to). Keep new
  content in the tree that matches its genre.
- When you change architecture, update the relevant file under
  `architecture/` and add a decision record for a significant choice
  (`decisions/template.md`).
- Keep these docs current as part of finishing a task — see AGENTS.md.
