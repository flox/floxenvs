import { describe, it, expect } from "vitest";
import { encodeSelection, decodeSelection } from "./selectionHash";

describe("selectionHash", () => {
  it("encodes empty selection as empty string", () => {
    expect(encodeSelection({ agents: [], skills: [], tools: [] })).toBe("");
  });

  it("encodes only non-empty groups", () => {
    expect(
      encodeSelection({ agents: ["claude-code"], skills: [], tools: [] }),
    ).toBe("#a=claude-code");
  });

  it("round-trips a multi-group selection", () => {
    const sel = {
      agents: ["claude-code", "codex"],
      skills: ["skills-agent-deck", "skills-caveman"],
      tools: ["skillcheck"],
    };
    expect(decodeSelection(encodeSelection(sel))).toEqual(sel);
  });

  it("decodes tolerantly: leading #, missing keys, empties", () => {
    expect(decodeSelection("")).toEqual({ agents: [], skills: [], tools: [] });
    expect(decodeSelection("#s=a,,b")).toEqual({
      agents: [],
      skills: ["a", "b"],
      tools: [],
    });
  });

  it("de-duplicates while preserving order", () => {
    expect(decodeSelection("#a=x,x,y").agents).toEqual(["x", "y"]);
  });
});
