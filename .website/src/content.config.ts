import { defineCollection, z } from "astro:content";
import { execFileSync } from "node:child_process";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import { parse as parseYaml } from "yaml";
import { parseInstalledPackages } from "./lib/parseManifest";
import {
  MetricsSchema,
  defaultMetrics,
  type Metrics,
} from "./lib/metricsSchema";

const REPO_ROOT = path.resolve(import.meta.dirname, "..", "..");

// Best-effort last-commit ISO date for a directory. Falls back
// to "" when git is missing (CI shallow clones, etc).
function gitLastCommitISO(absDir: string): string {
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

const baseFields = {
  name: z.string(),
  title: z.string(),
  publisher: z.string().default("flox"),
  tagline: z.string(),
  // Optional SEO overrides. seo_title replaces the auto-built page
  // <title>; seo_description replaces the meta description. Use them
  // when the tagline alone misses key intent keywords for SERP / AI
  // overview citation (e.g., surfacing "pgvector" on the postgres
  // page or "install" on a tool page).
  seo_title: z.string().optional(),
  seo_description: z.string().optional(),
  intro: z.string().optional(),
  summary: z.array(z.string()).default([]),
  category: z.enum(["ai","language","database","service","tool","runtime"]),
  ai_role: z
    .enum(["agent","llm-runtime","rag","memory","orchestrator","tooling","ide"])
    .optional(),
  tags: z.array(z.string()).default([]),
  stack: z.array(z.string()).default([]),
  featured: z.boolean().default(false),
  combines_well_with: z.array(z.string()).default([]),
  status: z.enum(["stable","beta","experimental","deprecated"]).default("beta"),
  license: z.string().optional(),
  upstream: z
    .object({
      name: z.string(),
      url: z.string().url(),
      license: z.string().optional(),
    })
    .optional(),
  maintainer: z.string().optional(),
  systems: z.array(z.string()).default([]),
  links: z.record(z.string(), z.string()).default({}),
};

const envSchema = z.object({
  kind: z.literal("env"),
  ...baseFields,
  install: z
    .object({
      include: z.string().optional(),
      activate: z.string().optional(),
      docker: z.string().optional(),
    })
    .optional(),
  example: z
    .object({ command: z.string(), description: z.string().optional() })
    .optional(),
  recipes: z
    .array(
      z.object({
        name: z.string(),
        title: z.string().optional(),
        start_services: z.boolean().default(false),
        features: z.array(z.string()).default([]),
      }),
    )
    .default([]),
  includes_envs: z.array(z.string()).default([]),
  requires_envs: z.array(z.string()).default([]),
  bundles_pkgs: z.array(z.string()).default([]),
  manifest_install: z
    .array(z.object({ name: z.string(), path: z.string() }))
    .default([]),
  readme: z.string().default(""),
  recipe_readme: z.string().default(""),
  recipe_manifest: z.string().default(""),
  last_updated: z.string().default(""),
  metrics: MetricsSchema,
});

const pkgSchema = z.object({
  kind: z.literal("pkg"),
  subkind: z.enum(["plain","plugin","skill"]).default("plain"),
  ...baseFields,
  install: z.object({ pkg: z.string() }).optional(),
  plugin_for: z.string().nullable().optional(),
  skill_for: z.string().nullable().optional(),
  readme: z.string().default(""),
  last_updated: z.string().default(""),
  metrics: MetricsSchema,
});

async function readFileOrEmpty(p: string): Promise<string> {
  try {
    return await fs.readFile(p, "utf-8");
  } catch {
    return "";
  }
}

const METRICS_ROOT = path.join(REPO_ROOT, "audit");

async function loadMetrics(
  kind: "env" | "pkg",
  name: string,
): Promise<Metrics> {
  const p = path.join(METRICS_ROOT, kind, name, "metrics.json");
  try {
    const raw = await fs.readFile(p, "utf-8");
    return MetricsSchema.parse(JSON.parse(raw));
  } catch {
    return defaultMetrics({ kind, name });
  }
}

async function loadEnvs() {
  const entries = await fs.readdir(REPO_ROOT, { withFileTypes: true });
  const out: unknown[] = [];
  for (const e of entries) {
    if (!e.isDirectory()) continue;
    if (e.name.startsWith(".")) continue;
    if (e.name === "scripts") continue;
    if (e.name.endsWith("-demo")) continue;

    const metaPath = path.join(REPO_ROOT, e.name, "meta.yaml");
    let meta: Record<string, unknown>;
    try {
      meta = parseYaml(await fs.readFile(metaPath, "utf-8"));
    } catch {
      continue;
    }
    if (meta?.kind !== "env") continue;

    const manifestToml = await readFileOrEmpty(
      path.join(REPO_ROOT, e.name, ".flox/env/manifest.toml"),
    );
    const manifestInstall = parseInstalledPackages(manifestToml);
    const readme = await readFileOrEmpty(
      path.join(REPO_ROOT, e.name, "README.md"),
    );
    const demoDir = `${e.name}-demo`;
    const recipeReadme = await readFileOrEmpty(
      path.join(REPO_ROOT, demoDir, "README.md"),
    );
    const recipeManifest = await readFileOrEmpty(
      path.join(REPO_ROOT, demoDir, ".flox/env/manifest.toml"),
    );

    const metrics = await loadMetrics("env", e.name);
    const lastUpdated = gitLastCommitISO(path.join(REPO_ROOT, e.name));
    out.push({
      id: e.name,
      ...meta,
      manifest_install: manifestInstall,
      readme,
      recipe_readme: recipeReadme,
      recipe_manifest: recipeManifest,
      last_updated: lastUpdated,
      metrics,
    });
  }
  return out;
}

async function loadPkgs() {
  const pkgsDir = path.join(REPO_ROOT, ".flox", "pkgs");
  let entries: import("node:fs").Dirent[] = [];
  try {
    entries = await fs.readdir(pkgsDir, { withFileTypes: true });
  } catch {
    return [];
  }
  const out: unknown[] = [];
  for (const e of entries) {
    if (!e.isDirectory()) continue;
    const metaPath = path.join(pkgsDir, e.name, "meta.yaml");
    let meta: Record<string, unknown>;
    try {
      meta = parseYaml(await fs.readFile(metaPath, "utf-8"));
    } catch {
      continue;
    }
    if (meta?.kind !== "pkg") continue;
    const readme = await readFileOrEmpty(
      path.join(pkgsDir, e.name, "README.md"),
    );
    const metrics = await loadMetrics("pkg", e.name);
    const lastUpdated = gitLastCommitISO(path.join(pkgsDir, e.name));
    out.push({
      id: e.name,
      ...meta,
      readme,
      last_updated: lastUpdated,
      metrics,
    });
  }
  return out;
}

export const collections = {
  envs: defineCollection({
    loader: async () => (await loadEnvs()) as never,
    schema: envSchema,
  }),
  packages: defineCollection({
    loader: async () => (await loadPkgs()) as never,
    schema: pkgSchema,
  }),
};
