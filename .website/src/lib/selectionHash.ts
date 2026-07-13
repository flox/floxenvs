export interface Selection {
  agents: string[];
  skills: string[];
  tools: string[];
}

const KEYS: ReadonlyArray<[keyof Selection, string]> = [
  ["agents", "a"],
  ["skills", "s"],
  ["tools", "t"],
];

function uniq(values: string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const v of values) {
    if (v && !seen.has(v)) {
      seen.add(v);
      out.push(v);
    }
  }
  return out;
}

export function encodeSelection(sel: Selection): string {
  const parts: string[] = [];
  for (const [group, key] of KEYS) {
    const vals = uniq(sel[group] ?? []);
    if (vals.length) parts.push(`${key}=${vals.join(",")}`);
  }
  return parts.length ? `#${parts.join("&")}` : "";
}

export function decodeSelection(hash: string): Selection {
  const out: Selection = { agents: [], skills: [], tools: [] };
  const body = hash.replace(/^#/, "");
  if (!body) return out;
  const byKey = new Map(KEYS.map(([group, key]) => [key, group]));
  for (const pair of body.split("&")) {
    const eq = pair.indexOf("=");
    if (eq < 0) continue;
    const key = pair.slice(0, eq);
    const group = byKey.get(key);
    if (!group) continue;
    out[group] = uniq(pair.slice(eq + 1).split(","));
  }
  return out;
}
