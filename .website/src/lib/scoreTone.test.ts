import { describe, expect, it } from "vitest";
import { scoreTone } from "./scoreTone";

describe("scoreTone", () => {
  it("returns 'green' for 80+", () => {
    expect(scoreTone(82)).toBe("green");
    expect(scoreTone(100)).toBe("green");
  });
  it("returns 'amber' for 60..79", () => {
    expect(scoreTone(60)).toBe("amber");
    expect(scoreTone(79)).toBe("amber");
  });
  it("returns 'red' for <60", () => {
    expect(scoreTone(59)).toBe("red");
    expect(scoreTone(0)).toBe("red");
  });
});
