import { describe, expect, it } from "vitest";
import { computeAffinityEdges } from "./affinityEdges";

const items = [
  {
    kind: "env" as const,
    name: "claude",
    combines_well_with: ["pkg:graphify", "env:playwright"],
    bundles_pkgs: ["claude-code"],
  },
  {
    kind: "env" as const,
    name: "playwright",
    combines_well_with: [],
    bundles_pkgs: ["playwright-cli"],
  },
  {
    kind: "pkg" as const,
    name: "graphify",
    combines_well_with: ["env:claude"],
    bundled_by: [],
  },
  {
    kind: "pkg" as const,
    name: "claude-code",
    combines_well_with: [],
    bundled_by: ["claude"],
  },
];

describe("computeAffinityEdges", () => {
  it("emits an undirected edge per combines_well_with link", () => {
    const edges = computeAffinityEdges(items);
    expect(edges).toContainEqual({
      from: { kind: "env", name: "claude" },
      to: { kind: "pkg", name: "graphify" },
      source: "combines_well_with",
    });
  });

  it("emits a bundling edge per bundles_pkgs link", () => {
    const edges = computeAffinityEdges(items);
    expect(edges).toContainEqual({
      from: { kind: "env", name: "claude" },
      to: { kind: "pkg", name: "claude-code" },
      source: "bundles",
    });
  });

  it("deduplicates symmetric combines_well_with references", () => {
    const edges = computeAffinityEdges(items);
    const cwEdges = edges.filter(e => e.source === "combines_well_with");
    const claudeGraphify = cwEdges.filter(e =>
      (e.from.name === "claude" && e.to.name === "graphify") ||
      (e.from.name === "graphify" && e.to.name === "claude")
    );
    expect(claudeGraphify.length).toBe(1);
  });
});
