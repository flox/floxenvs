import { describe, it, expect } from "vitest";
import { buildManifest, buildInstallCommands } from "./buildSnippet";
import type { WizardItem } from "./wizardItems";

const SEL: WizardItem[] = [
  { id: "claude-code", name: "Claude Code", kind: "agent",
    installPkg: "flox/claude-code", audit: null },
  { id: "skills-agent-deck", name: "Agent Deck", kind: "skill",
    installPkg: "flox/skills-agent-deck", audit: { overall: 34, status: "risk" } },
];

describe("buildManifest", () => {
  it("emits an [install] table pinned to flox/<pkg>", () => {
    const out = buildManifest(SEL);
    expect(out).toContain("[install]");
    expect(out).toContain('claude-code.pkg-path = "flox/claude-code"');
    expect(out).toContain('skills-agent-deck.pkg-path = "flox/skills-agent-deck"');
  });

  it("returns just the [install] header for an empty selection", () => {
    expect(buildManifest([]).trim()).toBe("[install]");
  });
});

describe("buildInstallCommands", () => {
  it("emits one flox install line per item", () => {
    expect(buildInstallCommands(SEL)).toBe(
      "flox install flox/claude-code\nflox install flox/skills-agent-deck",
    );
  });
});
