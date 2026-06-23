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
    const fresh = [{ ...item("b"), audit: null }];
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
