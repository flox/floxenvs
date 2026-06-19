# data.json — unified catalog + audit artifact — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task.
> Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce one `data.json` (catalog metadata + inline,
pre-computed audit per item), served at
`https://flox.github.io/floxenvs/data.json`, generated incrementally in
the website workflow, consumed by the flox-ai TUI (scores while browsing
+ a detail screen). Remove `ai-catalog.json`.

**Architecture:** The website workflow already audits changed items
(`audit-item` → per-item `metrics.json`). A new aggregation step
**fetches the currently-published `data.json`, upserts only the checked
items (catalog metadata + the item's `MetricsSchema`-normalized
`metrics.json` as `audit`), and preserves the rest**, then writes
`data.json` into the site's `dist/`. The Go TUI changes its fetch URL,
gains an `Audit` field on `catalog.Item`, shows the overall score in the
list, and adds one detail modal.

**Tech Stack:** TypeScript (Astro 5 + zod), Go (Bubble Tea TUI),
GitHub Actions, vitest, `go test`.

**Spec:** `docs/superpowers/specs/2026-06-19-audit-data-json-design.md`

**Canonical `audit` shape:** the existing
`.website/src/lib/metricsSchema.ts` `Metrics` (zod) — that is what the
website already parses every `metrics.json` into. `data.json`'s `audit`
field is exactly a `Metrics` object (no `rawByTool`). The Go TUI mirrors
it. No new audit shape is invented.

**Working branch:** `feature/audit-data-json` (already created off main;
the spec/PRD is committed there).

---

## File Structure

**Website (producer):**
- `.website/src/lib/dataJson.ts` — **new.** The `data.json` envelope
  type, `DataItem` type (`CatalogItem` + `audit: Metrics | null`), and
  the pure merge function `mergeDataJson(existing, fresh)`.
- `.website/src/lib/dataJson.test.ts` — **new.** vitest for the merge +
  envelope.
- `.website/src/lib/aiCatalog.ts` — **modify.** Drop the maturity
  `status` field from `CatalogItem`/`PkgData` mapping and the
  `STATUS_RANK` ordering; ranking becomes featured → name.
- `.website/src/lib/aiCatalog.test.ts` — **modify.** Drop `status`
  assertions.
- `.website/src/pages/ai-catalog.json.ts` — **delete.**
- `.website/scripts/build-data-json.mjs` — **new.** Node build step:
  read staged `metrics.json` files + the catalog, fetch the published
  `data.json`, merge, write `.website/public/data.json`.
- `.github/workflows/website.yml` — **modify.** Replace the
  `ai-catalog` expectations; add a "Build data.json" step in
  `collect-metrics` (or `build-site`) that runs the script.

**TUI (consumer), all under `.flox/pkgs/flox-ai/internal`:**
- `catalog/catalog.go` — **modify.** Add `Audit *Audit` to `Item`;
  drop `Status`; add `Envelope` type; change `Parse` to decode the
  envelope.
- `catalog/audit.go` — **new.** The Go `Audit` struct mirroring
  `Metrics`.
- `catalog/catalog_test.go` — **modify/new.** Envelope parse test.
- `catalog/load.go` — **modify.** `DefaultURL` → `…/data.json`.
- `catalog/embedded.json` — **regenerate** into the envelope shape.
- `tui/*` — **modify.** Show `Audit.Overall` in list rows; add the
  detail modal (mirror the existing `modalReview` rendering).

---

## Phase 0 — Canonical shape + website catalog cleanup

### Task 1: Drop maturity `status` from the catalog mapping

**Files:**
- Modify: `.website/src/lib/aiCatalog.ts`
- Test: `.website/src/lib/aiCatalog.test.ts`

- [ ] **Step 1: Update the failing test first**

In `aiCatalog.test.ts`, the `toCatalogItem` expectation currently
includes `status: "beta"` (or similar). Remove the `status` key from the
expected object, and remove the `status` field from the `caveman`
fixture. Add an ordering test that does not depend on status:

```ts
it("ranks featured first, then by name", () => {
  const mk = (name: string, featured: boolean): PkgData => ({
    name, title: name, subkind: "skill", tagline: "", category: "ai",
    featured, install: { pkg: "" },
  });
  const out = buildCatalog([mk("b", false), mk("a", false), mk("c", true)]);
  expect(out.map((i) => i.id)).toEqual(["c", "a", "b"]);
});
```

- [ ] **Step 2: Run it, expect failure**

Run: `cd .website && npm run -s test -- aiCatalog`
Expected: FAIL — `status` still emitted / `STATUS_RANK` ordering differs.

- [ ] **Step 3: Implement**

In `.website/src/lib/aiCatalog.ts`:
- Remove `status` from `interface CatalogItem`.
- Remove `status?: string;` from `interface PkgData`.
- In `toCatalogItem`, delete the `status: p.status ?? "beta",` line.
- Delete the `STATUS_RANK` constant.
- Replace `rankItems` body with featured → name only:

```ts
export function rankItems(items: CatalogItem[]): CatalogItem[] {
  return [...items].sort((a, b) => {
    if (a.featured !== b.featured) return a.featured ? -1 : 1;
    return a.name.localeCompare(b.name);
  });
}
```

- [ ] **Step 4: Run, expect pass**

Run: `cd .website && npm run -s test -- aiCatalog`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add .website/src/lib/aiCatalog.ts .website/src/lib/aiCatalog.test.ts
git commit -m "feat(website): drop maturity status from catalog mapping"
```

---

## Phase 1 — data.json generation (website)

### Task 2: `dataJson.ts` — envelope, item type, merge function

**Files:**
- Create: `.website/src/lib/dataJson.ts`
- Test: `.website/src/lib/dataJson.test.ts`

- [ ] **Step 1: Write the failing test**

```ts
import { describe, it, expect } from "vitest";
import { mergeDataJson, type DataJson } from "./dataJson";
import type { CatalogItem } from "./aiCatalog";

const item = (id: string): CatalogItem => ({
  id, name: id, type: "skill", for: "claude-code", description: "",
  tags: [], categories: [], featured: false, link: "", installPkg: `flox/${id}`,
});

describe("mergeDataJson", () => {
  it("upserts checked items and preserves the rest", () => {
    const existing: DataJson = {
      schema_version: 1, generated_at: "t0", commit: "old",
      items: [
        { ...item("a"), audit: null },
        { ...item("b"), audit: null },
      ],
    };
    const fresh = [{ ...item("b"), audit: null }]; // b re-audited, score below
    const merged = mergeDataJson(existing, fresh, { full: false, commit: "new", generatedAt: "t1" });
    expect(merged.items.map((i) => i.id).sort()).toEqual(["a", "b"]);
    expect(merged.commit).toBe("new");
  });

  it("full run replaces the entire item set (drops deletions)", () => {
    const existing: DataJson = {
      schema_version: 1, generated_at: "t0", commit: "old",
      items: [{ ...item("a"), audit: null }, { ...item("gone"), audit: null }],
    };
    const fresh = [{ ...item("a"), audit: null }];
    const merged = mergeDataJson(existing, fresh, { full: true, commit: "new", generatedAt: "t1" });
    expect(merged.items.map((i) => i.id)).toEqual(["a"]);
  });
});
```

- [ ] **Step 2: Run it, expect failure**

Run: `cd .website && npm run -s test -- dataJson`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement `dataJson.ts`**

```ts
import type { CatalogItem } from "./aiCatalog";
import type { Metrics } from "./metricsSchema";

export interface DataItem extends CatalogItem {
  audit: Metrics | null;
}

export interface DataJson {
  schema_version: 1;
  generated_at: string;
  commit: string;
  items: DataItem[];
}

export interface MergeOpts {
  full: boolean;        // true = authoritative rebuild (drops deletions)
  commit: string;
  generatedAt: string;
}

// Upsert `fresh` items into `existing` by id; preserve unchecked items.
// A full run keeps only `fresh` (so deleted packages drop out).
export function mergeDataJson(
  existing: DataJson | null,
  fresh: DataItem[],
  opts: MergeOpts,
): DataJson {
  const byId = new Map<string, DataItem>();
  if (!opts.full && existing) {
    for (const it of existing.items) byId.set(it.id, it);
  }
  for (const it of fresh) byId.set(it.id, it);
  const items = [...byId.values()].sort((a, b) => {
    if (a.featured !== b.featured) return a.featured ? -1 : 1;
    return a.name.localeCompare(b.name);
  });
  return { schema_version: 1, generated_at: opts.generatedAt, commit: opts.commit, items };
}
```

- [ ] **Step 4: Run, expect pass**

Run: `cd .website && npm run -s test -- dataJson`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add .website/src/lib/dataJson.ts .website/src/lib/dataJson.test.ts
git commit -m "feat(website): data.json envelope + merge function"
```

### Task 3: `build-data-json.mjs` — the aggregation build step

**Files:**
- Create: `.website/scripts/build-data-json.mjs`

This script runs in CI AFTER metrics are staged into
`.website/src/content/metrics/<kind>/<name>.json` (the existing
`collect-metrics` job already stages those, including prior metrics for
unchanged items). It reads the package catalog from the same source the
deleted endpoint used, attaches each item's staged metrics as `audit`,
fetches the live `data.json`, merges, and writes
`.website/public/data.json`.

- [ ] **Step 1: Read the existing metrics-staging step to confirm paths**

Read `.github/workflows/website.yml` job `collect-metrics` and
`.website/src/content.config.ts` `loadMetrics`. Confirm: staged metrics
live at `.website/src/content/metrics/{env,pkg,skill,agent}/<name>.json`
and parse through `MetricsSchema`. Confirm the catalog source is the
`packages` content collection (meta.yaml). The script must read meta.yaml
directly (it runs as plain Node, not inside Astro) — meta.yaml files live
at `.flox/pkgs/<name>/meta.yaml`. Use the same field mapping as
`toCatalogItem`.

- [ ] **Step 2: Implement the script**

```js
// .website/scripts/build-data-json.mjs
// Aggregate catalog metadata + staged audit metrics into data.json,
// merging into the currently-published data.json.
import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { execSync } from "node:child_process";
import { parse as parseYaml } from "yaml";
import { MetricsSchema } from "../src/lib/metricsSchema.ts";
import { toCatalogItem, isFragmentPkg } from "../src/lib/aiCatalog.ts";
import { mergeDataJson } from "../src/lib/dataJson.ts";

const REPO = join(import.meta.dirname, "..", "..");
const PUBLISHED = "https://flox.github.io/floxenvs/data.json";

const FULL = process.argv.includes("--full");      // no-arg dispatch / all
const onlyArg = process.argv.find((a) => a.startsWith("--only="));
const only = onlyArg ? onlyArg.slice("--only=".length).split(",") : null;

// 1. catalog metadata for the checked items (all fragments, or `only`)
const pkgsDir = join(REPO, ".flox", "pkgs");
const names = (only ?? readdirSync(pkgsDir))
  .filter((n) => existsSync(join(pkgsDir, n, "meta.yaml")));

const fresh = [];
for (const name of names) {
  const meta = parseYaml(readFileSync(join(pkgsDir, name, "meta.yaml"), "utf8"));
  const pkg = { name, ...meta, install: meta.install };
  if (!isFragmentPkg(pkg)) continue;
  const item = toCatalogItem(pkg);
  // 2. attach staged audit metrics if present
  const kind = pkg.subkind === "agent" ? "agent" : "skill";
  const metricsPath = join(REPO, ".website", "src", "content", "metrics", kind, `${name}.json`);
  let audit = null;
  if (existsSync(metricsPath)) {
    audit = MetricsSchema.parse(JSON.parse(readFileSync(metricsPath, "utf8")));
  }
  fresh.push({ ...item, audit });
}

// 3. fetch published data.json (tolerate absence / first run)
let existing = null;
try {
  const res = await fetch(PUBLISHED);
  if (res.ok) existing = await res.json();
} catch { /* first run: no published data.json */ }

const commit = execSync("git rev-parse HEAD", { cwd: REPO }).toString().trim();
const generatedAt = new Date().toISOString();
const merged = mergeDataJson(existing, fresh, { full: FULL || only === null && false, commit, generatedAt });

const out = join(REPO, ".website", "public", "data.json");
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(merged, null, 2));
console.log(`data.json: ${merged.items.length} items (full=${FULL}, fresh=${fresh.length})`);
```

Note on `full`: pass `--full` when the run audited **all** packages
(dispatch no-arg / `items: all`); pass `--only=<csv>` when it audited a
subset (push/changed, or dispatch with a package). When `only` is null
and not `--full`, treat as full (safety: a run that built every fragment
is authoritative).

- [ ] **Step 3: Smoke-test locally**

Run:
```bash
cd .website && flox activate -- node scripts/build-data-json.mjs --full
```
Expected: writes `.website/public/data.json`; prints item count > 0;
`jq '.items[0] | {id, type, audit: (.audit!=null)}' public/data.json`
shows a real item.

- [ ] **Step 4: Commit**

```bash
git add .website/scripts/build-data-json.mjs
git commit -m "feat(website): build-data-json aggregation script"
```

### Task 4: Wire the workflow + remove ai-catalog.json

**Files:**
- Modify: `.github/workflows/website.yml`
- Delete: `.website/src/pages/ai-catalog.json.ts`

- [ ] **Step 1: Delete the endpoint**

```bash
git rm .website/src/pages/ai-catalog.json.ts
```

- [ ] **Step 2: Add `yaml` dep used by the script**

The script imports `yaml`. Check `.website/package.json` — Astro ships
`yaml` transitively, but make it explicit:
```bash
cd .website && npm install --save-dev yaml && cd ..
```
(If `yaml` already resolves, skip; confirm with `node -e "require('yaml')"`.)

- [ ] **Step 3: Add the build-data-json step to `build-site`**

In `.github/workflows/website.yml`, `build-site` job, AFTER "Download
staged metrics" and BEFORE "Build", add (this job already has the staged
metrics downloaded into `.website/src/content/metrics`):

```yaml
      - name: "Install flox"
        uses: "flox/install-flox-action@f6002ed63e483f134001de7b4b45be891e00b09f" # v2.5.1
      - name: "Build data.json"
        # FULL when this run audited all items; else only the changed set.
        env:
          ITEMS: ${{ inputs.items }}
        shell: "flox activate -- bash -e {0}"
        run: |
          cd .website
          if [ "${ITEMS:-changed}" = "all" ] || [ -z "${ITEMS:-}" ]; then
            node scripts/build-data-json.mjs --full
          else
            # ITEMS is csv of <kind>:<name>; pass the names
            only=$(echo "$ITEMS" | tr ',' '\n' | sed 's/^[^:]*://' | paste -sd, -)
            node scripts/build-data-json.mjs --only="$only"
          fi
```

`data.json` lands in `.website/public/`, so `astro build` copies it into
`dist/` and the existing `deploy` job publishes it to gh-pages at
`/floxenvs/data.json`.

- [ ] **Step 4: Confirm the dispatch input default means "all"**

Per the spec, dispatch with no package → all. In `website.yml`
`workflow_dispatch.inputs.items`, change the default from `"changed"` to
`"all"`, OR document that the empty/`all` path triggers `--full`. Keep
`workflow_call` (CI) passing `items: changed`.

- [ ] **Step 5: Validate YAML + commit**

Run: `ruby -ryaml -e 'YAML.load_file(".github/workflows/website.yml")'`
Expected: no error.
```bash
git add .github/workflows/website.yml
git rm .website/src/pages/ai-catalog.json.ts
git add .website/package.json .website/package-lock.json
git commit -m "ci(website): generate+publish data.json; remove ai-catalog.json"
```

---

## Phase 2 — TUI consumes data.json

### Task 5: Go `Audit` struct mirroring `Metrics`

**Files:**
- Create: `.flox/pkgs/flox-ai/internal/catalog/audit.go`
- Test: `.flox/pkgs/flox-ai/internal/catalog/audit_test.go`

- [ ] **Step 1: Write the failing test**

```go
package catalog

import "testing"

func TestAuditJSON(t *testing.T) {
	data := []byte(`{"overall":89,"status":"stable",
	  "quality":{"score":92,"checks":[{"id":"skill-tools","weight":40,"pass":true,"note":"92"}]},
	  "reliability":{"score":85},
	  "security":{"score":90,"cap":100,"scanners":[{"tool":"gitleaks","level":"none","status":"clean"}],
	    "findings":[{"tool":"skillcheck","level":"LOW","status":"open","note":"x"}]},
	  "impact":{"pass":3,"total":4,"score":78}}`)
	var a Audit
	if err := json.Unmarshal(data, &a); err != nil {
		t.Fatal(err)
	}
	if a.Overall != 89 || a.Status != "stable" {
		t.Fatalf("overall/status: %+v", a)
	}
	if len(a.Quality.Checks) != 1 || a.Quality.Checks[0].ID != "skill-tools" {
		t.Fatalf("checks: %+v", a.Quality.Checks)
	}
	if len(a.Security.Findings) != 1 || a.Security.Findings[0].Level != "LOW" {
		t.Fatalf("findings: %+v", a.Security.Findings)
	}
}
```
(Add `"encoding/json"` import to the test.)

- [ ] **Step 2: Run, expect failure**

Run: `cd .flox/pkgs/flox-ai && flox activate -- go test ./internal/catalog/ -run TestAuditJSON`
Expected: FAIL — `Audit` undefined.

- [ ] **Step 3: Implement `audit.go`**

```go
package catalog

// Audit mirrors the website MetricsSchema (the normalized metrics.json).
// It is the per-item audit embedded in data.json.
type Audit struct {
	Overall int    `json:"overall"`
	Status  string `json:"status"` // stable|warn|risk|missing
	Quality struct {
		Score  int `json:"score"`
		Checks []struct {
			ID     string `json:"id"`
			Pass   bool   `json:"pass"`
			Weight int    `json:"weight"`
			Note   string `json:"note"`
		} `json:"checks"`
	} `json:"quality"`
	Reliability struct {
		Score              int    `json:"score"`
		CIGreenStreakDays  int    `json:"ci_green_streak_days"`
		LastTestAt         string `json:"last_test_at"`
		LockfileFresh      bool   `json:"lockfile_fresh"`
		TestDurationS      float64 `json:"test_duration_s"`
		Note               string `json:"note"`
	} `json:"reliability"`
	Security struct {
		Score    int `json:"score"`
		Cap      int `json:"cap"`
		Scanners []struct {
			Tool   string `json:"tool"`
			Level  string `json:"level"`
			Status string `json:"status"`
		} `json:"scanners"`
		Findings []struct {
			Tool   string `json:"tool"`
			Level  string `json:"level"`
			Count  int    `json:"count"`
			Status string `json:"status"`
			Note   string `json:"note"`
		} `json:"findings"`
	} `json:"security"`
	Impact struct {
		Pass  int  `json:"pass"`
		Total int  `json:"total"`
		Score *int `json:"score"`
	} `json:"impact"`
}
```

- [ ] **Step 4: Run, expect pass**

Run: `cd .flox/pkgs/flox-ai && flox activate -- go test ./internal/catalog/ -run TestAuditJSON`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add .flox/pkgs/flox-ai/internal/catalog/audit.go .flox/pkgs/flox-ai/internal/catalog/audit_test.go
git commit -m "feat(flox-ai): catalog Audit struct mirroring metrics schema"
```

### Task 6: Envelope parse + `Audit` on `Item`; drop `Status`

**Files:**
- Modify: `.flox/pkgs/flox-ai/internal/catalog/catalog.go`
- Test: `.flox/pkgs/flox-ai/internal/catalog/catalog_test.go`

- [ ] **Step 1: Write the failing test**

```go
func TestParseEnvelope(t *testing.T) {
	data := []byte(`{"schema_version":1,"generated_at":"t","commit":"c",
	  "items":[{"id":"skills-x","name":"X","type":"skill","installPkg":"flox/skills-x",
	    "audit":{"overall":80,"status":"stable"}}]}`)
	items, err := Parse(data)
	if err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 || items[0].ID != "skills-x" {
		t.Fatalf("items: %+v", items)
	}
	if items[0].Audit == nil || items[0].Audit.Overall != 80 {
		t.Fatalf("audit: %+v", items[0].Audit)
	}
}
```

- [ ] **Step 2: Run, expect failure**

Run: `cd .flox/pkgs/flox-ai && flox activate -- go test ./internal/catalog/ -run TestParseEnvelope`
Expected: FAIL — `Parse` decodes a bare array; `Audit` field missing.

- [ ] **Step 3: Implement**

In `catalog.go`: remove the `Status string` field from `Item`; add
`Audit *Audit \`json:"audit,omitempty"\`` to `Item`; add the envelope
type and rewrite `Parse`:

```go
// Envelope is the top-level data.json document.
type Envelope struct {
	SchemaVersion int    `json:"schema_version"`
	GeneratedAt   string `json:"generated_at"`
	Commit        string `json:"commit"`
	Items         []Item `json:"items"`
}

// Parse decodes the data.json envelope into its items.
func Parse(data []byte) ([]Item, error) {
	var env Envelope
	if err := json.Unmarshal(data, &env); err != nil {
		return nil, err
	}
	return env.Items, nil
}
```

- [ ] **Step 4: Fix compile fallout**

Run: `cd .flox/pkgs/flox-ai && flox activate -- go build ./...`
Expected: errors anywhere `Item.Status` was read (likely
`internal/tui/view.go` or a card renderer). For each, replace the
maturity-status badge with the audit status/score (Task 8) or remove it.
Re-run until it builds.

- [ ] **Step 5: Run tests + commit**

Run: `cd .flox/pkgs/flox-ai && flox activate -- go test ./internal/catalog/`
Expected: PASS.
```bash
git add .flox/pkgs/flox-ai/internal/catalog/catalog.go .flox/pkgs/flox-ai/internal/catalog/catalog_test.go
git commit -m "feat(flox-ai): parse data.json envelope; Item.Audit; drop Status"
```

### Task 7: Point the TUI at data.json + regenerate embedded snapshot

**Files:**
- Modify: `.flox/pkgs/flox-ai/internal/catalog/load.go`
- Regenerate: `.flox/pkgs/flox-ai/internal/catalog/embedded.json`

- [ ] **Step 1: Change the URL**

In `load.go`:
```go
const DefaultURL = "https://flox.github.io/floxenvs/data.json"
```

- [ ] **Step 2: Regenerate the embedded snapshot in the envelope shape**

The embedded fallback must now be an `Envelope`. Regenerate it from the
freshly-built `data.json` (Task 3 smoke test output):
```bash
cp .website/public/data.json .flox/pkgs/flox-ai/internal/catalog/embedded.json
```
(If `.website/public/data.json` isn't present, run the Task 3 smoke test
first.)

- [ ] **Step 3: Verify load + tests**

Run: `cd .flox/pkgs/flox-ai && flox activate -- go test ./internal/catalog/`
Expected: PASS (embedded parses as an envelope).

- [ ] **Step 4: Commit**

```bash
git add .flox/pkgs/flox-ai/internal/catalog/load.go .flox/pkgs/flox-ai/internal/catalog/embedded.json
git commit -m "feat(flox-ai): TUI fetches data.json; embedded snapshot in envelope shape"
```

### Task 8: Show the overall score in list rows

**Files:**
- Modify: the TUI row renderer (find it first).

- [ ] **Step 1: Locate the row renderer**

Run: `cd .flox/pkgs/flox-ai && grep -rn "func.*render\|itemRow\|Title()" internal/tui/*.go | grep -iv _test`
Identify where each catalog row's text/badge is built (likely
`internal/tui/view.go` or a `list` delegate). Read it.

- [ ] **Step 2: Add a score badge**

Append the audit overall + status to each row when `it.Audit != nil`,
mirroring the existing status-glyph style in `internal/tui/glyphs.go`.
Example (adapt to the actual renderer):
```go
score := ""
if it.Audit != nil {
	score = fmt.Sprintf("  %d %s", it.Audit.Overall, it.Audit.Status)
}
```
Use the existing status icons in `glyphs.go` (stable/warn/risk) rather
than raw text if a mapping exists.

- [ ] **Step 3: Build + manual check**

Run: `cd .flox/pkgs/flox-ai && flox activate -- go build ./... && flox activate -- go test ./internal/tui/`
Expected: builds; tests pass. Manually: `flox-ai tui` shows scores on
rows (against the embedded snapshot).

- [ ] **Step 4: Commit**

```bash
git add .flox/pkgs/flox-ai/internal/tui/
git commit -m "feat(flox-ai): show audit score on catalog rows"
```

### Task 9: Audit detail modal

**Files:**
- Modify: `internal/tui/modal.go`, `internal/tui/keys.go`,
  `internal/tui/update.go`, `internal/tui/view.go` (mirror the existing
  `modalReview` master/detail).

- [ ] **Step 1: Read the existing `modalReview` implementation**

Run: `cd .flox/pkgs/flox-ai && grep -rn "modalReview" internal/tui/*.go`
Read how `modalReview` is opened (key), updated, and rendered (it already
shows audit results for installed skills). The new detail modal reuses
this exact pattern but renders the **selected catalog item's
`Audit`** (from data.json) instead of a live run.

- [ ] **Step 2: Add a modal mode + key binding**

In `internal/tui/modal.go` add `modalAuditDetail`. In
`internal/tui/keys.go` add a binding (e.g. `key.WithKeys("a")`,
`key.WithHelp("a", "audit detail")`), following the existing `Detail`
binding style.

- [ ] **Step 3: Render the detail**

In the view, when `modalAuditDetail` is active and the selected item has
`Audit != nil`, render:
- header: `name` + overall + status
- four dimension scores (quality / reliability / security / impact)
- security scanners (tool · level · status) and findings
  (tool · level · note) — this is the "why is the score low" content
- quality checks that failed (`!pass`) with their `note`

If `Audit == nil`, render "not audited yet" and a hint to run the live
review (existing `modalReview`).

- [ ] **Step 4: Build + tests**

Run: `cd .flox/pkgs/flox-ai && flox activate -- go build ./... && flox activate -- go test ./internal/tui/`
Expected: builds + passes. Add a `view_test.go` case asserting the
rendered detail contains the overall score and a finding note.

- [ ] **Step 5: Commit**

```bash
git add .flox/pkgs/flox-ai/internal/tui/
git commit -m "feat(flox-ai): audit detail modal from data.json"
```

---

## Phase 3 — Integration check

### Task 10: End-to-end dry run

- [ ] **Step 1: Build data.json for all items**

Run: `cd .website && flox activate -- node scripts/build-data-json.mjs --full`
Expected: `public/data.json` with every fragment; audited skills have a
non-null `audit`.

- [ ] **Step 2: Point the TUI at the local file (temporary)**

Serve `.website/public/data.json` locally and run the TUI against it:
```bash
cd .website/public && flox activate -- python3 -m http.server 8099 &
FLOX_AI_CATALOG_URL=http://localhost:8099/data.json flox-ai tui   # if env override exists; else temporarily edit DefaultURL
```
Expected: rows show real scores; the audit detail modal shows real
findings. Kill the server after.

- [ ] **Step 3: Full suite**

Run:
```bash
cd .website && npm run -s test && cd ..
cd .flox/pkgs/flox-ai && flox activate -- go test ./...
```
Expected: all pass.

- [ ] **Step 4: Open the PR**

```bash
git push -u origin feature/audit-data-json
gh pr create --base main --title "feat: data.json unified catalog+audit artifact" --body "Implements docs/superpowers/specs/2026-06-19-audit-data-json-design.md"
```

---

## Self-Review notes

- **Spec coverage:** one-file/two-consumers (Tasks 2,4,6,7); contents
  incl. all fragment types + inline audit (Tasks 3,5,6); pre-computed
  audit (Task 3); run-your-own stays (untouched `modalReview`, Task 9);
  minimal TUI + detail screen (Tasks 8,9); non-blocking publish
  (unchanged); incremental + merge (Tasks 2,3,4); parameterized scope
  (Task 4); remove ai-catalog.json (Task 4). Website redesign + blocking
  publish are out of scope (Follow-ups).
- **Known investigation points (read before coding, not placeholders):**
  the exact TUI row renderer (Task 8 Step 1) and `modalReview` pattern
  (Task 9 Step 1) must be read in-repo; the plan instructs mirroring the
  existing code rather than inventing it.
- **Shape note:** Go skill/agent `audit.Result` carries a top-level
  `findings` + `security.severity` not in `MetricsSchema`. The canonical
  `audit` is `MetricsSchema` (what the website parses today), so those
  extra fields are dropped on the website side. If skill security
  findings must appear in the detail modal, a small follow-up maps the Go
  top-level `findings` into `security.findings` during audit — out of
  scope here; the detail modal renders whatever `security.findings`/
  `scanners` + `quality.checks` contain.
