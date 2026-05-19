import { defineConfig } from "astro/config";
import preact from "@astrojs/preact";
import sitemap from "@astrojs/sitemap";
import tailwindcss from "@tailwindcss/vite";
import { execFileSync } from "node:child_process";
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

// Cache repeated lookups (one per directory) so the serialize
// callback stays cheap when called N times for the same dir.
const lastModCache = new Map();
function lastModFor(urlPath) {
  // Strip the base path so we can map cleanly back to a repo dir.
  // urlPath is the full https URL emitted by the sitemap integration.
  let p;
  try {
    p = new URL(urlPath).pathname;
  } catch {
    p = urlPath;
  }
  if (BASE && p.startsWith(BASE)) p = p.slice(BASE.length);
  // Normalise: strip leading + trailing slash
  p = p.replace(/^\/+/, "").replace(/\/+$/, "");

  const segments = p.split("/").filter(Boolean);
  let dir = null;
  if (segments.length === 0) {
    // Landing page — use build time
    return BUILD_TIME;
  }
  if (segments[0] === "envs" && segments[1] && segments.length === 2) {
    dir = path.join(REPO_ROOT, segments[1]);
  } else if (
    segments[0] === "packages" && segments[1] && segments.length === 2 &&
    segments[1] !== "plugins" && segments[1] !== "skills"
  ) {
    dir = path.join(REPO_ROOT, ".flox", "pkgs", segments[1]);
  }
  if (!dir) return BUILD_TIME;
  if (lastModCache.has(dir)) return lastModCache.get(dir);
  const t = gitLastCommitISO(dir) || BUILD_TIME;
  lastModCache.set(dir, t);
  return t;
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
