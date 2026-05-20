// .website/src/lib/metricsSchema.ts
//
// Uses `zod` directly (Astro 5 ships it as a transitive
// dependency, so `import { z } from "zod"` resolves
// without adding it to package.json). The schema is
// reused both by the Astro content loader (server side)
// and by vitest unit tests (Node, no Astro runtime).
import { z } from "zod";

const Check = z.object({
  id: z.string(),
  pass: z.boolean(),
  weight: z.number(),
  note: z.string().optional(),
});

const Quality = z.object({
  score: z.number().min(0).max(100),
  checks: z.array(Check).default([]),
});

const Reliability = z.object({
  ci_green_streak_days: z.number().default(0),
  last_test_at: z.string().default(""),
  lockfile_fresh: z.boolean().default(false),
  test_duration_s: z.number().default(0),
  score: z.number().min(0).max(100).default(0),
  note: z.string().default(""),
});

const Scanner = z.object({
  tool: z.string(),
  level: z.string().default("INFO"),
  status: z.string(),
});

const Finding = z.object({
  tool: z.string(),
  level: z.enum(["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO"]),
  count: z.number().optional(),
  status: z.string(),
  note: z.string().optional(),
});

const Security = z.object({
  score: z.number().min(0).max(100).default(0),
  cap: z.number().min(0).max(100).default(100),
  scanners: z.array(Scanner).default([]),
  findings: z.array(Finding).default([]),
});

const ImpactCase = z.object({
  id: z.string(),
  pass: z.boolean(),
  duration_s: z.number().default(0),
  note: z.string().default(""),
});

const Impact = z.object({
  pass: z.number().default(0),
  total: z.number().default(0),
  score: z.number().nullable().default(null),
  cases: z.array(ImpactCase).default([]),
});

const Identity = z.object({
  kind: z.enum(["env", "pkg"]),
  name: z.string(),
  dir: z.string().default(""),
});

export const MetricsSchema = z.object({
  identity: Identity,
  overall: z.number().min(0).max(100).default(0),
  status: z.enum(["stable", "warn", "risk", "missing"]).default("stable"),
  quality: Quality,
  reliability: Reliability,
  security: Security,
  impact: Impact,
});

export type Metrics = z.infer<typeof MetricsSchema>;

export function defaultMetrics(id: {
  kind: "env" | "pkg";
  name: string;
}): Metrics {
  return MetricsSchema.parse({
    identity: { kind: id.kind, name: id.name, dir: "" },
    overall: 0,
    status: "missing",
    quality: { score: 0, checks: [] },
    reliability: {
      ci_green_streak_days: 0,
      last_test_at: "",
      lockfile_fresh: false,
      test_duration_s: 0,
      score: 0,
      note: "",
    },
    security: { score: 0, cap: 100, scanners: [], findings: [] },
    impact: { pass: 0, total: 0, score: null, cases: [] },
  });
}
