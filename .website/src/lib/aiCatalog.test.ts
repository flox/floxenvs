import { describe, it, expect } from "vitest";
import {
  toCatalogItem,
  rankItems,
  buildCatalog,
  extractInstallPkg,
  isFragmentPkg,
  type PkgData,
} from "./aiCatalog";

const caveman: PkgData = {
  name: "claude-code-plugin-caveman",
  title: "Caveman",
  subkind: "plugin",
  plugin_for: "claude-code",
  intro: "Caveman intro.",
  summary: ["one", "two"],
  stack: ["bash"],
  license: "MIT",
  maintainer: "@rok",
  tagline: "Ultra-compressed agent communication plugin.\n",
  tags: ["claude-code", "plugin", "compression"],
  category: "ai",
  status: "beta",
  featured: false,
  links: {
    source: "https://github.com/flox/floxenvs/tree/main/x",
    floxhub: "https://hub.flox.dev/flox/claude-code-plugin-caveman",
  },
  install: {
    pkg: [
      "[install]",
      'claude-code.pkg-path = "flox/claude-code"',
      'claude-code.publisher = "flox"',
      'claude-code-plugin-caveman.pkg-path = "flox/claude-code-plugin-caveman"',
      'claude-code-plugin-caveman.publisher = "flox"',
    ].join("\n"),
  },
};

describe("toCatalogItem", () => {
  it("maps a plugin package to a catalog item", () => {
    const item = toCatalogItem(caveman);
    expect(item).toEqual({
      id: "claude-code-plugin-caveman",
      name: "Caveman",
      type: "plugin",
      for: "claude-code",
      description: "Ultra-compressed agent communication plugin.",
      tags: ["claude-code", "plugin", "compression"],
      categories: ["ai"],
      status: "beta",
      featured: false,
      link: "https://github.com/flox/floxenvs/tree/main/x",
      installPkg: "flox/claude-code-plugin-caveman",
      intro: "Caveman intro.",
      summary: ["one", "two"],
      stack: ["bash"],
      license: "MIT",
      maintainer: "@rok",
    });
  });

  it("extracts installPkg matching the package name, not the dep", () => {
    expect(toCatalogItem(caveman).installPkg).toBe(
      "flox/claude-code-plugin-caveman",
    );
  });
});

describe("rankItems", () => {
  it("sorts featured first, then by status rank, then title", () => {
    const items = [
      { ...toCatalogItem(caveman), name: "B", featured: false, status: "beta" },
      { ...toCatalogItem(caveman), name: "A", featured: true, status: "stable" },
      { ...toCatalogItem(caveman), name: "C", featured: false, status: "stable" },
    ];
    const ranked = rankItems(items);
    expect(ranked.map((i) => i.name)).toEqual(["A", "C", "B"]);
  });
});

describe("extractInstallPkg", () => {
  it("falls back to flox/<name> when install.pkg is absent", () => {
    const p: PkgData = {
      name: "skills-graphify",
      title: "Graphify",
      subkind: "skill",
      tagline: "x",
      category: "ai",
    };
    expect(extractInstallPkg(p)).toBe("flox/skills-graphify");
  });

  it("matches the package's own name, not a dependency line", () => {
    const p: PkgData = {
      name: "skills-graphify",
      title: "Graphify",
      subkind: "skill",
      tagline: "x",
      category: "ai",
      install: {
        pkg: [
          "[install]",
          'claude-code.pkg-path = "flox/claude-code"',
          'skills-graphify.pkg-path = "flox/skills-graphify"',
        ].join("\n"),
      },
    };
    expect(extractInstallPkg(p)).toBe("flox/skills-graphify");
  });
});

describe("isFragmentPkg", () => {
  const base = { name: "x", title: "X", tagline: "x", category: "ai" };
  it("includes plugin/skill/agent/rule", () => {
    for (const subkind of ["plugin", "skill", "agent", "rule"]) {
      expect(isFragmentPkg({ ...base, subkind } as PkgData)).toBe(true);
    }
  });
  it("excludes plain", () => {
    expect(isFragmentPkg({ ...base, subkind: "plain" } as PkgData)).toBe(false);
  });
});

describe("buildCatalog", () => {
  it("filters non-fragment pkgs, maps, and ranks", () => {
    const pkgs: PkgData[] = [
      { name: "claude-code", title: "Claude Code", subkind: "plain",
        tagline: "agent", category: "ai", featured: true, status: "stable" },
      { name: "a-skill", title: "Zeta", subkind: "skill",
        tagline: "z", category: "ai", featured: false, status: "beta" },
      { name: "b-plugin", title: "Alpha", subkind: "plugin",
        tagline: "a", category: "ai", featured: true, status: "stable" },
    ];
    const out = buildCatalog(pkgs);
    // plain excluded; featured plugin first, then the beta skill
    expect(out.map((i) => i.id)).toEqual(["b-plugin", "a-skill"]);
  });
});
