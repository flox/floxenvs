# PRD — flox-ai TUI and in-process audit

Status: Living
Owner: flox-ai

## Problem

A Flox environment can carry a curated set of AI fragments — rules,
skills, agents, plugins — but there was no pleasant way to discover what
is available, install it into the environment, judge its quality, and
launch an agent with it. The pieces existed (a catalog, a separate
quality scorer, a launcher) but the user had to stitch them together on
the command line, and the quality scorer was a separate binary the tool
shelled out to.

## Goals

- Let a user browse the curated catalog and install/uninstall fragments
  into the active environment without leaving the terminal.
- Let a user judge a skill or agent's quality and see why it scores as
  it does, in the same place.
- Let a user launch an agent (Claude Code, or Agent Deck) with the
  environment's fragments injected.
- Make the whole thing feel like one coherent tool, not a bag of
  subcommands.

## Users

- A developer using a flox-ai-enabled environment who wants to set up or
  tune their AI agent context.
- A skill/agent author who wants to score their work and fix what the
  audit flags.

## Requirements

- **Browse**: search the catalog by text and `#tag`; a sensible default
  list (top picks, or what is installed).
- **Install**: stage changes and apply them as `flox install` /
  `flox uninstall` against the active environment.
- **Review**: score every present skill/agent in-process; show overall +
  per-dimension scores, the per-tool checks, the findings, and raw tool
  output, drillable. Prompt to install missing quality tools first.
- **Launch**: confirm, then run the selected agent with fragments
  injected; support Claude Code and Agent Deck.
- **Fit in**: run only inside a Flox environment; require a Nerd Font;
  full mouse support; light/dark aware; theming.
- **Scriptable**: a non-interactive `flox-ai audit <path>` with JSON and
  a `--threshold` CI gate.

## Success signals

- A user can go from "fresh environment" to "Claude launched with the
  right fragments" without leaving the TUI.
- A skill author can run the review, read why a tool failed, fix it, and
  re-run — all in one screen.
- The audit score in the TUI and from `flox-ai audit` agree, because
  they are the same engine.

## Non-goals

- Authoring fragments inside the TUI (it installs and reviews; authoring
  happens in the editor).
- Supporting terminals without a Nerd Font ([ADR 0002](
  ../decisions/0002-nerd-font-required.md)).
- Running outside a Flox environment for the TUI ([ADR 0007](
  ../decisions/0007-require-flox-environment.md)); `audit` and `doctor`
  work without one.

## History

The TUI and catalog were built on the branch `feature/flox-ai-tui`
(PR #4211). Agent Deck launch support landed independently on main
(PR #4374) and was integrated by rebase ([ADR 0008](
../decisions/0008-squash-then-rebase.md)). The audit engine was absorbed
from the standalone `review-skills` binary ([ADR 0003](
../decisions/0003-absorb-audit-engine-in-process.md)).
