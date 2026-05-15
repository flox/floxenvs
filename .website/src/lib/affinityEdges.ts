import type { Kind } from "./kindNames";

export interface AffinityNode {
  kind: Kind;
  name: string;
}

export interface AffinityEdge {
  from: AffinityNode;
  to: AffinityNode;
  source: "combines_well_with" | "bundles";
}

interface AffinityInput {
  kind: Kind;
  name: string;
  combines_well_with: string[];
  bundles_pkgs?: string[];
  bundled_by?: string[];
}

function parsePrefixed(ref: string): AffinityNode | null {
  const m = /^(env|pkg):(.+)$/.exec(ref);
  if (!m) return null;
  return { kind: m[1] as Kind, name: m[2] };
}

function edgeKey(e: AffinityEdge): string {
  const a = `${e.from.kind}:${e.from.name}`;
  const b = `${e.to.kind}:${e.to.name}`;
  const [first, second] = [a, b].sort();
  return `${e.source}|${first}|${second}`;
}

export function computeAffinityEdges(
  items: AffinityInput[],
): AffinityEdge[] {
  const seen = new Set<string>();
  const edges: AffinityEdge[] = [];

  const push = (e: AffinityEdge) => {
    const k = edgeKey(e);
    if (seen.has(k)) return;
    seen.add(k);
    edges.push(e);
  };

  for (const item of items) {
    const from: AffinityNode = { kind: item.kind, name: item.name };
    for (const ref of item.combines_well_with) {
      const to = parsePrefixed(ref);
      if (!to) continue;
      push({ from, to, source: "combines_well_with" });
    }
    if (item.kind === "env" && item.bundles_pkgs) {
      for (const pkgName of item.bundles_pkgs) {
        push({
          from,
          to: { kind: "pkg", name: pkgName },
          source: "bundles",
        });
      }
    }
  }
  return edges;
}
