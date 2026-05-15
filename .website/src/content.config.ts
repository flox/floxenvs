import { defineCollection, z } from "astro:content";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import { parse as parseYaml } from "yaml";
import { parseInstalledPackages } from "./lib/parseManifest";

const REPO_ROOT = path.resolve(import.meta.dirname, "..", "..");

const baseFields = {
  name: z.string(),
  title: z.string(),
  publisher: z.string().default("flox"),
  tagline: z.string(),
  summary: z.array(z.string()).default([]),
  category: z.enum(["ai","language","database","service","tool","runtime"]),
  ai_role: z
    .enum(["agent","llm-runtime","rag","orchestrator","tooling","ide"])
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
});

const pkgSchema = z.object({
  kind: z.literal("pkg"),
  subkind: z.enum(["plain","plugin","skill"]).default("plain"),
  ...baseFields,
  install: z.object({ pkg: z.string() }).optional(),
  plugin_for: z.string().nullable().optional(),
  skill_for: z.string().nullable().optional(),
  readme: z.string().default(""),
});

async function readFileOrEmpty(p: string): Promise<string> {
  try {
    return await fs.readFile(p, "utf-8");
  } catch {
    return "";
  }
}

async function loadEnvs() {
  const entries = await fs.readdir(REPO_ROOT, { withFileTypes: true });
  const out: unknown[] = [];
  for (const e of entries) {
    if (!e.isDirectory()) continue;
    if (e.name.startsWith(".") || e.name === "site") continue;
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

    out.push({
      id: e.name,
      ...meta,
      manifest_install: manifestInstall,
      readme,
      recipe_readme: recipeReadme,
      recipe_manifest: recipeManifest,
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
    out.push({ id: e.name, ...meta, readme });
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
