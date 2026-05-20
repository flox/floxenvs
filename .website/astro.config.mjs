import { defineConfig } from "astro/config";
import preact from "@astrojs/preact";
import sitemap from "@astrojs/sitemap";
import tailwindcss from "@tailwindcss/vite";
import { execFileSync } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";

const SITE = process.env.SITE_URL ?? "https://flox.github.io";
const BASE = process.env.BASE_PATH ?? "/floxenvs";

// Resolve the repo root from this config file (.website/astro.config.mjs).
const REPO_ROOT = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);

// Best-effort last-commit ISO date for a directory. Empty
// string when git is unavailable (CI shallow clone, etc).
function gitLastCommitISO(absDir) {
  try {
    const out = execFileSync(
      "git",
      ["log", "-1", "--format=%cI", "--", absDir],
      { cwd: REPO_ROOT, stdio: ["ignore", "pipe", "ignore"] },
    );
    return out.toString().trim();
  } catch {
    return "";
  }
}

const BUILD_TIME = new Date().toISOString();

// Cache per-directory git lookups so the serialize callback
// stays cheap when called N times for the same dir. Returns
// the empty string when git has no history for that path —
// callers must do the BUILD_TIME fallback themselves so a
// missing-history sibling cannot poison `newest()` of peers.
const lastModCache = new Map();
function dirLastMod(dir) {
  if (lastModCache.has(dir)) return lastModCache.get(dir);
  const t = gitLastCommitISO(dir);
  lastModCache.set(dir, t);
  return t;
}

// Newest of a list of ISO timestamps (greatest lex order).
function newest(values) {
  let best = "";
  for (const v of values) if (v && v > best) best = v;
  return best;
}

// Cached newest-of-collection-members lookup. Used for index
// and taxonomy pages so /envs/ reflects the newest env
// directory and /packages/plugins/ reflects the newest plugin.
const collNewestCache = new Map();
function newestUnder(root, filter) {
  const key = `${root}::${filter?.toString() ?? ""}`;
  if (collNewestCache.has(key)) return collNewestCache.get(key);
  const entries = (() => {
    try {
      return fs.readdirSync(root, { withFileTypes: true })
        .filter((e) => e.isDirectory())
        .filter((e) => !filter || filter(e.name));
    } catch {
      return [];
    }
  })();
  const stamps = entries.map((e) => dirLastMod(path.join(root, e.name)));
  const t = newest(stamps) || BUILD_TIME;
  collNewestCache.set(key, t);
  return t;
}

function lastModFor(urlPath) {
  let p;
  try {
    p = new URL(urlPath).pathname;
  } catch {
    p = urlPath;
  }
  if (BASE && p.startsWith(BASE)) p = p.slice(BASE.length);
  p = p.replace(/^\/+/, "").replace(/\/+$/, "");

  const segments = p.split("/").filter(Boolean);
  // Landing page
  if (segments.length === 0) {
    return newest([
      newestUnder(REPO_ROOT, (n) =>
        !n.startsWith(".") && n !== "site" && n !== ".website" &&
        n !== "scripts" && n !== "node_modules" && !n.endsWith("-demo")),
      newestUnder(path.join(REPO_ROOT, ".flox", "pkgs"), null),
    ]);
  }
  // Env detail
  if (segments[0] === "envs" && segments[1] && segments.length === 2) {
    return dirLastMod(path.join(REPO_ROOT, segments[1])) || BUILD_TIME;
  }
  // Pkg detail
  if (
    segments[0] === "packages" && segments[1] && segments.length === 2 &&
    segments[1] !== "plugins" && segments[1] !== "skills"
  ) {
    return dirLastMod(path.join(REPO_ROOT, ".flox", "pkgs", segments[1]))
      || BUILD_TIME;
  }
  // Envs index — newest env dir
  if (segments[0] === "envs" && segments.length === 1) {
    return newestUnder(REPO_ROOT, (n) =>
      !n.startsWith(".") && n !== "site" && n !== ".website" &&
      n !== "scripts" && n !== "node_modules" && !n.endsWith("-demo"));
  }
  // Packages index — newest pkg dir
  if (segments[0] === "packages" && segments.length === 1) {
    return newestUnder(path.join(REPO_ROOT, ".flox", "pkgs"), null);
  }
  // Plugins / skills filtered indexes
  if (
    segments[0] === "packages" && segments.length === 2 &&
    (segments[1] === "plugins" || segments[1] === "skills")
  ) {
    const prefix = segments[1] === "plugins"
      ? "claude-code-plugin-"
      : null;
    return newestUnder(path.join(REPO_ROOT, ".flox", "pkgs"), (n) =>
      prefix ? n.startsWith(prefix) : (n === "skill-coreutils" || n.startsWith("skills-")));
  }
  // Category / tag pages — fall back to all-content newest
  if (segments[0] === "categories" || segments[0] === "tags") {
    return newest([
      newestUnder(REPO_ROOT, (n) =>
        !n.startsWith(".") && n !== "site" && n !== ".website" &&
        n !== "scripts" && n !== "node_modules" && !n.endsWith("-demo")),
      newestUnder(path.join(REPO_ROOT, ".flox", "pkgs"), null),
    ]);
  }
  // Anything else (search, compare, og endpoints) — build time
  return BUILD_TIME;
}

// Post-build patch for `dist/sitemap-index.xml`. @astrojs/sitemap
// emits the index without a `<lastmod>` on its `<sitemap>` entries,
// which makes the index opaque to Googlebot's differential crawl
// scheduling. We patch in the newest `<lastmod>` from sitemap-0.xml.
function sitemapIndexLastmod() {
  return {
    name: "sitemap-index-lastmod",
    hooks: {
      "astro:build:done": ({ dir }) => {
        const outDir = fileURLToPath(dir);
        const idx = path.join(outDir, "sitemap-index.xml");
        const sm0 = path.join(outDir, "sitemap-0.xml");
        if (!fs.existsSync(idx) || !fs.existsSync(sm0)) return;
        const body = fs.readFileSync(sm0, "utf8");
        const stamps = [...body.matchAll(/<lastmod>([^<]+)<\/lastmod>/g)]
          .map((m) => m[1]);
        const newestStamp = stamps.sort().pop() || BUILD_TIME;
        const patched = fs.readFileSync(idx, "utf8").replace(
          /(<sitemap><loc>[^<]+<\/loc>)(<\/sitemap>)/,
          `$1<lastmod>${newestStamp}</lastmod>$2`,
        );
        fs.writeFileSync(idx, patched);
      },
    },
  };
}

export default defineConfig({
  site: SITE,
  base: BASE,
  output: "static",
  trailingSlash: "always",
  integrations: [
    preact(),
    sitemap({
      // Exclude utility / non-content pages: client-side search,
      // OG image endpoints. These provide no SERP value and would
      // dilute the sitemap.
      filter: (page) => {
        try {
          const p = new URL(page).pathname;
          if (p.endsWith("/search/")) return false;
          if (p.includes("/og/")) return false;
          return true;
        } catch {
          return true;
        }
      },
      serialize(item) {
        return { ...item, lastmod: lastModFor(item.url) };
      },
    }),
    sitemapIndexLastmod(),
  ],
  vite: { plugins: [tailwindcss()] },
});
