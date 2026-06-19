# `data.json` — unified catalog + audit artifact (design / PRD)

**Status:** Draft for review
**Date:** 2026-06-19
**Scope:** the `data.json` artifact, its generation in the website
workflow, and wiring the flox-ai TUI to it. The website's own
consumption + visual/structural redesign is a **separate, later**
sub-project.

---

## Goal

Produce a single JSON artifact — `data.json` — that carries **all
fragment metadata plus pre-computed audit results**, served alongside
the website at `https://flox.github.io/floxenvs/data.json`. The flox-ai
TUI downloads it at startup and renders real data (catalog + scores +
a detail report), replacing today's metadata-only feed and the fake /
live-only audit data. The website will read the same file during its
later redesign.

## Why (background)

Today there are **two** artifacts and the TUI sees no audit data:

- `ai-catalog.json` (built by the site, served on gh-pages) — fragment
  **metadata only**. This is what the TUI fetches at startup
  (`catalog.DefaultURL`), caches to `~/.cache/flox-ai/catalog.json`,
  with an embedded fallback.
- per-item `audit/<kind>/<name>/metrics.json` — the **audit** scores +
  findings, produced by the website `audit-item` job
  (`scripts/run-audit.sh`, which delegates skills/agents to the Go
  `review-skills`/`flox-ai audit` engine). Consumed only by the
  **website** package pages.

The TUI's `catalog.Item` has no score fields; its only audit path is a
modal that runs `review-skills audit` **live** on installed skills
(slow, needs tools installed). We want audit pre-computed and bundled.

## Requirements

### Functional

1. **One file, two consumers.** `data.json` is the single source for
   both the TUI and (later) the website. `ai-catalog.json` is removed.
2. **Contents.** Every fragment the catalog lists — **skills, agents,
   and any other types (plugins, rules, …), including older package
   types** — appears in `data.json` with its full metadata. Skills and
   agents (and any audited type) also carry their audit results inline.
   The shape is built to **expand**: new fragment types and new fields
   must not break consumers.
3. **Pre-computed audit.** Audit runs **ahead of time** in CI (the
   website workflow's `audit` step) and is embedded in `data.json`. The
   TUI does not need to run audits to show scores.
4. **Run-your-own audit stays.** The TUI keeps its existing path to run
   an audit locally against installed skills (the live `review-skills`
   modal). Two ways to get audit data: served (default) + on-demand.
5. **TUI: minimal change.** No TUI redesign. Only: (a) fetch `data.json`
   instead of `ai-catalog.json`; (b) carry audit data on each item;
   (c) show the overall score + audit status while browsing; (d) add
   **one** detail screen/modal, opened via a shortcut, that shows the
   full per-item report (dimension scores + findings) so a user can tell
   *why* a score is low — a real vulnerability vs. just sloppy.
6. **Incremental audit + merge.** A push that changes only some
   packages must audit **only those** (the per-changed-item matrix
   already does this via `changed-items.sh`). Crucially, the aggregator
   starts from the **currently-published `data.json`**, **upserts only
   the checked items by `id`**, and **preserves every unchecked item
   verbatim** — it never re-audits or drops the rest. (This generalizes
   the workflow's existing "fetch prior metrics for unchanged items"
   step to the whole `data.json`.) A full run (all packages) rebuilds
   the authoritative set and is what reconciles deletions.
7. **Parameterized scope (mirrors `ci_pkgs`).** Manual dispatch with
   **no package argument → audit/update all packages**; with a
   **package argument → only that one**. Automatic push / `workflow_call`
   from CI → **changed** items only. Same mental model as build/publish,
   but the work here is auditing.
8. **Non-blocking publish.** Publishing does **not** gate on audit
   results now. (See Follow-ups.)

### Non-functional

- `data.json` must stay a reasonable download for a CLI startup fetch.
  We include findings (the useful detail) but **exclude** raw per-tool
  output dumps (`rawByTool`) — those remain CLI-only via
  `flox-ai audit --report`.
- Backward/forward tolerance: consumers ignore unknown fields; `audit`
  is absent/`null` for unaudited items.

## `data.json` schema

A top-level envelope + an array of items. Each item = today's catalog
metadata, plus an optional `audit` object that is today's
`metrics.json` (minus `rawByTool`).

```jsonc
{
  "schema_version": 1,
  "generated_at": "2026-06-19T12:00:00Z",   // build timestamp
  "commit": "<git sha the audit ran against>",
  "items": [
    {
      // ── catalog metadata (today's CatalogItem; NO maturity `status`) ──
      "id": "skills-superpowers",
      "name": "Superpowers",
      "type": "skill",                 // plugin|skill|agent|rule|… (open-ended)
      "for": "claude-code",
      "description": "…",
      "tags": ["…"],
      "categories": ["ai"],
      "featured": true,
      "link": "https://github.com/…",
      "homepage": "https://…",         // optional
      "installPkg": "flox/skills-superpowers",
      "intro": "…",                    // optional
      "summary": ["…"],                // optional
      "stack": ["bash"],               // optional
      "license": "MIT",                // optional
      "maintainer": "@rok",            // optional

      // ── audit (today's metrics.json minus rawByTool); null if unaudited ──
      "audit": {
        "overall": 89,
        "status": "stable",            // stable|warn|risk|missing (audit health)
        "quality": {
          "score": 92,
          "checks": [{ "id": "skill-tools", "weight": 40, "pass": true, "note": "92" }]
        },
        "reliability": {
          "score": 85, "ci_green_streak_days": 12, "last_test_at": "…",
          "lockfile_fresh": true, "test_duration_s": 4.2, "note": ""
        },
        "security": {
          "score": 90, "cap": 100, "severity": "none",
          "scanners": [{ "tool": "gitleaks", "level": "none", "status": "clean" }],
          "findings": [{ "tool": "skillcheck", "level": "LOW", "count": 2, "status": "…", "note": "…" }]
        },
        "impact": {
          "score": 78, "estimated": false, "pass": 3, "total": 4,
          "cases": [{ "id": "…", "pass": true, "duration_s": 1.1, "note": "" }]
        },
        "findings": [
          { "tool": "skillspector", "severity": "warning", "rule": "broad-glob",
            "message": "broad glob in allowed-tools", "file": "SKILL.md",
            "line": 14, "fixable": false }
        ]
      }
    }
  ]
}
```

Notes:

- **Only one status exists** — `audit.status` (health). The former
  catalog maturity `status` is dropped; revisit later if needed.
- `type` is **open-ended** (string), so new fragment kinds are additive.
- Catalog ordering (was maturity-ranked) becomes **featured first, then
  name A→Z**; score-ranked ordering is a later option.
- `audit` reuses the existing `metrics.json` structure verbatim (so the
  Go `audit.Result` and the website `metricsSchema.ts` are the source of
  truth) — minus `rawByTool`.

## Generation (website workflow `audit` step)

The website workflow already audits each changed item
(`audit-item` → `metrics.json`) and collects metrics
(`collect-metrics`). The scope of what gets audited is the workflow's
existing matrix (`detect-changed` / `changed-items.sh`), driven by:

| Trigger | Scope audited |
| --- | --- |
| push / `workflow_call` (CI) | **changed** items only |
| `workflow_dispatch`, no package arg | **all** packages |
| `workflow_dispatch`, package arg | **that package** only |

(This matches `ci_pkgs`'s dispatch model. The workflow already has an
`items` input — `changed` \| `all` \| csv; the dispatch default should be
aligned so "no arg" means **all**.)

The new aggregation runs after metrics are staged and is a **merge**, not
a rebuild-from-scratch:

1. **Fetch the currently-published `data.json`** from
   `https://flox.github.io/floxenvs/data.json` (empty set if absent).
2. Build catalog metadata for the **checked** items (reusing the
   `aiCatalog.ts` logic), and attach each checked item's freshly-staged
   `metrics.json` (drop `rawByTool`) as `audit`.
3. **Upsert by `id`:** replace the checked items in the fetched
   `data.json`; **leave every other item untouched.** A full ("all")
   run replaces the entire `items` set (authoritative — this is how
   deleted packages drop out).
4. Stamp `schema_version`, `generated_at`, `commit`.
5. Write `data.json` into the published site root so it deploys to
   `https://flox.github.io/floxenvs/data.json`.
6. **Remove** the `ai-catalog.json` endpoint.

(Exact placement — Astro endpoint vs. a post-`collect-metrics` build
step — is an implementation-plan decision; the merge contract above is
what matters. The fetch-and-merge mirrors the existing "Fetch prior
metrics for unchanged items" step, lifted to the `data.json` level.)

## TUI changes (flox-ai)

- `internal/catalog`: change `DefaultURL` to `…/data.json`; parse the new
  envelope; add an `Audit` field to `catalog.Item` (a struct mirroring
  the `audit` object). Cache + embedded-fallback behavior unchanged.
- `internal/tui`:
  - List rows show `audit.overall` + a status badge (real data replaces
    fake).
  - **New detail screen/modal** (shortcut key) rendering the audit
    breakdown: the four dimension scores, security scanners, and
    `findings` (tool, severity, file:line, message) — answering "why is
    the score low."
  - Keep the existing live `review-skills` modal (run-your-own audit).

## Out of scope (this sub-project)

- **Website redesign** — visual + structural rewrite, and rewiring the
  website to read `data.json`. Separate later sub-project.
- Any change to *what* the audit measures or *which* tools run.

## Follow-ups (recorded, not now)

- **Blocking publish on audit.** Today publishing is non-blocking. Later,
  reject/refuse to publish skills with certain vulnerabilities
  (severity threshold gate in the publish path).
- **Website consuming `data.json`** as part of the redesign.
- Score-ranked catalog ordering once maturity `status` is reconsidered.

## Open questions

- None blocking. Implementation-plan will decide the exact generation
  mechanism (Astro route vs. post-collect build step) and the precise
  TUI shortcut key + detail layout.
