import { describe, it, expect } from "vitest";
import { dataJsonToItems, partition } from "./wizardItems";

const RAW = {
  items: [
    { id: "claude-code", name: "Claude Code", type: "agent",
      installPkg: "flox/claude-code" },
    { id: "skills-agent-deck", name: "Agent Deck", type: "skill",
      for: "claude-code", installPkg: "flox/skills-agent-deck",
      audit: { overall: 34, status: "risk" } },
    { id: "skillcheck", name: "skillcheck", type: "skill",
      installPkg: "flox/skillcheck" },
  ],
};

describe("dataJsonToItems", () => {
  it("maps fields and defaults audit to null", () => {
    const items = dataJsonToItems(RAW);
    const agent = items.find((i) => i.id === "claude-code")!;
    expect(agent).toMatchObject({
      id: "claude-code",
      kind: "agent",
      installPkg: "flox/claude-code",
      audit: null,
    });
  });

  it("derives installPkg when absent", () => {
    const items = dataJsonToItems({
      items: [{ id: "skills-x", name: "X", type: "skill" }],
    });
    expect(items[0].installPkg).toBe("flox/skills-x");
  });

  it("carries audit through for skills", () => {
    const deck = dataJsonToItems(RAW).find((i) => i.id === "skills-agent-deck")!;
    expect(deck.audit).toEqual({ overall: 34, status: "risk" });
  });
});

describe("partition", () => {
  it("splits agents, skills, and tools by kind", () => {
    const { agents, skills, tools } = partition(dataJsonToItems(RAW));
    expect(agents.map((i) => i.id)).toEqual(["claude-code"]);
    expect(skills.map((i) => i.id)).toEqual(["skills-agent-deck"]);
    expect(tools.map((i) => i.id)).toEqual(["skillcheck"]);
  });
});
