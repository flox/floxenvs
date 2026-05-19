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
// stays cheap when called N times for the same dir.
const lastModCache = new Map();
function dirLastMod(dir) {
  if (lastModCache.has(dir)) return lastModCache.get(dir);
  const t = gitLastCommitISO(dir) || BUILD_TIME;
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
    return dirLastMod(path.join(REPO_ROOT, segments[1]));
  }
  // Pkg detail
  if (
    segments[0] === "packages" && segments[1] && segments.length === 2 &&
    segments[1] !== "plugins" && segments[1] !== "skills"
  ) {
    return dirLastMod(path.join(REPO_ROOT, ".flox", "pkgs", segments[1]));
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

export default defineConfig({
  site: SITE,
  base: BASE,
  output: "static",
  trailingSlash: "always",
  integrations: [
    preact(),
    sitemap({
      serialize(item) {
        return { ...item, lastmod: lastModFor(item.url) };
      },
    }),
  ],
  vite: { plugins: [tailwindcss()] },
});
