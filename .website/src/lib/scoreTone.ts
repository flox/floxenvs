export type Tone = "green" | "amber" | "red";

export function scoreTone(score: number): Tone {
  if (score >= 80) return "green";
  if (score >= 60) return "amber";
  return "red";
}
