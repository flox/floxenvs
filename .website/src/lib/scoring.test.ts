// .website/src/lib/scoring.test.ts
import { describe, expect, it } from "vitest";
import { overallStatus, capLabel } from "./scoring";

describe("overallStatus", () => {
  it("returns 'stable' at 80+", () => {
    expect(overallStatus(87)).toBe("stable");
    expect(overallStatus(80)).toBe("stable");
  });

  it("returns 'warn' between 60 and 79", () => {
    expect(overallStatus(75)).toBe("warn");
    expect(overallStatus(60)).toBe("warn");
  });

  it("returns 'risk' below 60", () => {
    expect(overallStatus(59)).toBe("risk");
    expect(overallStatus(0)).toBe("risk");
  });
});

describe("capLabel", () => {
  it("describes the cap reason", () => {
    expect(capLabel(50)).toBe("Capped at 50 by CRITICAL finding");
    expect(capLabel(75)).toBe("Capped at 75 by HIGH finding");
    expect(capLabel(100)).toBeNull();
  });
});
