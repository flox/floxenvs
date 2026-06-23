export type WizardKind = "agent" | "skill" | "tool";

export interface WizardItem {
  id: string;
  name: string;
  kind: WizardKind;
  installPkg: string;
  for?: string;
  audit: { overall: number; status: string } | null;
}

export interface RawDataJson {
  items: Array<{
    id: string;
    name: string;
    type: string;
    for?: string;
    installPkg?: string;
    audit?: { overall?: number; status?: string } | null;
  }>;
}

// Audit tools shipped in this repo. Items with these ids are the
// "scanners" the builder offers in its audit-tools step, regardless of
// their data.json `type`.
export const TOOL_IDS: ReadonlySet<string> = new Set([
  "skillcheck",
  "skillspector",
  "claudelint",
  "skill-tools",
  "skill-validator",
]);

function classify(id: string, type: string): WizardKind {
  if (TOOL_IDS.has(id)) return "tool";
  if (type === "agent") return "agent";
  return "skill";
}

export function dataJsonToItems(data: RawDataJson): WizardItem[] {
  return (data.items ?? []).map((it) => {
    const a = it.audit;
    const audit =
      a && typeof a.overall === "number"
        ? { overall: a.overall, status: a.status ?? "unknown" }
        : null;
    return {
      id: it.id,
      name: it.name,
      kind: classify(it.id, it.type),
      installPkg: it.installPkg ?? `flox/${it.id}`,
      for: it.for,
      audit,
    };
  });
}

export function partition(items: WizardItem[]): {
  agents: WizardItem[];
  skills: WizardItem[];
  tools: WizardItem[];
} {
  return {
    agents: items.filter((i) => i.kind === "agent"),
    skills: items.filter((i) => i.kind === "skill"),
    tools: items.filter((i) => i.kind === "tool"),
  };
}
