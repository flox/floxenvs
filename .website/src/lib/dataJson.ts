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
