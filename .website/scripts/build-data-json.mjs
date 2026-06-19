// .website/scripts/build-data-json.mjs
//
// Aggregation step: reads meta.yaml from every package, attaches staged
// metrics (if present), fetches the live data.json, merges, and writes
// .website/public/data.json.
//
// Invocation (from .website/ dir):
//   node --experimental-strip-types scripts/build-data-json.mjs [--full] [--only=a,b]
//
// --full        authoritative rebuild (drops deleted packages from output)
// --only=a,b    upsert only the named packages, preserve the rest

import {
  readFileSync,
  writeFileSync,
  readdirSync,
  existsSync,
  mkdirSync,
} from "node:fs";
import { join, dirname } from "node:path";
import { execSync } from "node:child_process";
import { parse as parseYaml } from "yaml";
import { MetricsSchema } from "../src/lib/metricsSchema.ts";
import { toCatalogItem, isFragmentPkg } from "../src/lib/aiCatalog.ts";
import { mergeDataJson } from "../src/lib/dataJson.ts";

const REPO = join(import.meta.dirname, "..", "..");
const PUBLISHED = "https://flox.github.io/floxenvs/data.json";

const FULL = process.argv.includes("--full");
const onlyArg = process.argv.find((a) => a.startsWith("--only="));
const only = onlyArg ? onlyArg.slice("--only=".length).split(",") : null;

const pkgsDir = join(REPO, ".flox", "pkgs");
const names = (only ?? readdirSync(pkgsDir)).filter((n) =>
  existsSync(join(pkgsDir, n, "meta.yaml")),
);

const fresh = [];
for (const name of names) {
  // Fail fast, but name the offending package: a malformed meta.yaml or
  // metrics.json is a real error to fix, not something to silently drop
  // (dropping would look like a deletion on a full run).
  try {
    const meta = parseYaml(
      readFileSync(join(pkgsDir, name, "meta.yaml"), "utf8"),
    );
    const pkg = { name, ...meta };
    if (!isFragmentPkg(pkg)) continue;
    const item = toCatalogItem(pkg);
    const kind = pkg.subkind === "agent" ? "agent" : "skill";
    const metricsPath = join(
      REPO,
      ".website",
      "src",
      "content",
      "metrics",
      kind,
      `${name}.json`,
    );
    let audit = null;
    if (existsSync(metricsPath)) {
      audit = MetricsSchema.parse(
        JSON.parse(readFileSync(metricsPath, "utf8")),
      );
    }
    fresh.push({ ...item, audit });
  } catch (e) {
    throw new Error(`build-data-json: failed processing ${name}: ${e.message}`);
  }
}

let existing = null;
try {
  const res = await fetch(PUBLISHED);
  if (res.ok) existing = await res.json();
} catch {
  /* first run or network unavailable */
}

const commit = execSync("git rev-parse HEAD", { cwd: REPO })
  .toString()
  .trim();
const generatedAt = new Date().toISOString();
// No --only means we processed every package, so the output is
// authoritative — treat it as a full rebuild (drops deleted packages).
const isDefaultRun = only === null;
const isFull = FULL || isDefaultRun;
const merged = mergeDataJson(existing, fresh, {
  full: isFull,
  commit,
  generatedAt,
});

const out = join(REPO, ".website", "public", "data.json");
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify(merged, null, 2));
console.log(
  `data.json: ${merged.items.length} items (full=${isFull}, fresh=${fresh.length})`,
);
