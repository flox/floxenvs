import { describe, it, expect } from "vitest";
import { STEPS, initialState, wizardReducer } from "./wizardState";

describe("wizardReducer", () => {
  it("clamps next/prev within bounds", () => {
    let s = initialState();
    expect(s.stepIndex).toBe(0);
    s = wizardReducer(s, { type: "prev" });
    expect(s.stepIndex).toBe(0);
    for (let i = 0; i < 10; i++) s = wizardReducer(s, { type: "next" });
    expect(s.stepIndex).toBe(STEPS.length - 1);
  });

  it("toggles an id in a group on and off", () => {
    let s = initialState();
    s = wizardReducer(s, { type: "toggle", group: "agents", id: "claude-code" });
    expect(s.selection.agents).toEqual(["claude-code"]);
    s = wizardReducer(s, { type: "toggle", group: "agents", id: "claude-code" });
    expect(s.selection.agents).toEqual([]);
  });

  it("goto clamps to valid range", () => {
    let s = initialState();
    s = wizardReducer(s, { type: "goto", stepIndex: 99 });
    expect(s.stepIndex).toBe(STEPS.length - 1);
    s = wizardReducer(s, { type: "goto", stepIndex: -5 });
    expect(s.stepIndex).toBe(0);
  });

  it("seeds selection from initialState", () => {
    const s = initialState({ agents: ["codex"], skills: [], tools: [] });
    expect(s.selection.agents).toEqual(["codex"]);
  });
});
