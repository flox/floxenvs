// .website/src/lib/metricsSchema.test.ts
import { describe, expect, it } from "vitest";
import {
  MetricsSchema,
  defaultMetrics,
} from "./metricsSchema";

describe("MetricsSchema", () => {
  it("accepts a complete metrics.json", () => {
    const parsed = MetricsSchema.parse({
      identity: { kind: "env", name: "claude", dir: "claude" },
      overall: 87,
      status: "stable",
      quality: { score: 82, checks: [] },
      reliability: {
        ci_green_streak_days: 14,
        last_test_at: "2026-05-10",
        lockfile_fresh: true,
        test_duration_s: 30,
        score: 95,
        note: "",
      },
      security: {
        score: 100, cap: 100, scanners: [], findings: [],
      },
      impact: {
        pass: 17, total: 19, score: 89, cases: [],
      },
    });
    expect(parsed.overall).toBe(87);
  });

  it("defaultMetrics returns a safe empty record", () => {
    const d = defaultMetrics({ kind: "pkg", name: "x" });
    expect(d.overall).toBe(0);
    expect(d.status).toBe("missing");
    expect(d.security.scanners).toEqual([]);
  });

  it.each(["skill", "agent"] as const)(
    "accepts a metrics.json with identity.kind = %s",
    (kind) => {
      const parsed = MetricsSchema.parse({
        identity: { kind, name: "humanizer", dir: ".flox/pkgs/x" },
        overall: 80,
        status: "stable",
        quality: {
          score: 81,
          checks: [
            { id: "skill-tools", pass: true, weight: 40, note: "82" },
          ],
        },
        reliability: { score: 70 },
        security: { score: 100, cap: 100, severity: "none" },
        impact: { score: 70 },
      });
      expect(parsed.identity.kind).toBe(kind);
    },
  );

  it("defaultMetrics works for skill and agent kinds", () => {
    expect(defaultMetrics({ kind: "skill", name: "s" }).identity.kind).toBe(
      "skill",
    );
    expect(defaultMetrics({ kind: "agent", name: "a" }).identity.kind).toBe(
      "agent",
    );
  });
});
