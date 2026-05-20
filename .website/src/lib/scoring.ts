// .website/src/lib/scoring.ts
export type Status = "stable" | "warn" | "risk";

export function overallStatus(overall: number): Status {
  if (overall >= 80) return "stable";
  if (overall >= 60) return "warn";
  return "risk";
}

export function capLabel(cap: number): string | null {
  if (cap === 50) return "Capped at 50 by CRITICAL finding";
  if (cap === 75) return "Capped at 75 by HIGH finding";
  return null;
}
