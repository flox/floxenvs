import type { APIRoute } from "astro";
import { getCollection } from "astro:content";
import { buildCatalog, type PkgData } from "../lib/aiCatalog";

// Static endpoint: GET /ai-catalog.json — the curated fragment catalog
// the flox-ai TUI consumes. Built from the `packages` content
// collection (sourced from .flox/pkgs/*/meta.yaml), filtered to
// Claude Code fragment subkinds.
export const GET: APIRoute = async () => {
  const pkgs = await getCollection("packages");
  const items = buildCatalog(pkgs.map((p) => p.data as unknown as PkgData));
  return new Response(JSON.stringify(items, null, 2), {
    headers: { "Content-Type": "application/json" },
  });
};
