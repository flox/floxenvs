import { useEffect, useRef } from "preact/hooks";
import type { AffinityEdge } from "../lib/affinityEdges";

interface Props {
  edges: AffinityEdge[];
  nodes: { kind: "env" | "pkg"; name: string; title: string; href: string }[];
}

const KIND_FILL: Record<string, string> = {
  env: "var(--color-kind-env)",
  pkg: "var(--color-kind-pkg)",
};

export default function AffinityGraph({ edges, nodes }: Props) {
  const svgRef = useRef<SVGSVGElement>(null);

  useEffect(() => {
    if (!svgRef.current) return;
    const W = svgRef.current.clientWidth;
    const H = svgRef.current.clientHeight;
    const n = nodes.length;
    const cx = W / 2;
    const cy = H / 2;
    const r = Math.min(W, H) / 2 - 40;
    const positions = new Map<string, { x: number; y: number }>();
    nodes.forEach((node, i) => {
      const theta = (i / n) * 2 * Math.PI;
      positions.set(`${node.kind}:${node.name}`, {
        x: cx + r * Math.cos(theta),
        y: cy + r * Math.sin(theta),
      });
    });

    const svg = svgRef.current;
    svg.innerHTML = "";

    for (const e of edges) {
      const a = positions.get(`${e.from.kind}:${e.from.name}`);
      const b = positions.get(`${e.to.kind}:${e.to.name}`);
      if (!a || !b) continue;
      const line = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "line"
      );
      line.setAttribute("x1", String(a.x));
      line.setAttribute("y1", String(a.y));
      line.setAttribute("x2", String(b.x));
      line.setAttribute("y2", String(b.y));
      line.setAttribute("stroke", "currentColor");
      line.setAttribute("stroke-opacity", "0.15");
      line.setAttribute(
        "stroke-width",
        e.source === "bundles" ? "2" : "1"
      );
      svg.appendChild(line);
    }
    for (const node of nodes) {
      const p = positions.get(`${node.kind}:${node.name}`)!;
      const g = document.createElementNS("http://www.w3.org/2000/svg", "g");
      const link = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "a"
      );
      link.setAttribute("href", node.href);
      const circle = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "circle"
      );
      circle.setAttribute("cx", String(p.x));
      circle.setAttribute("cy", String(p.y));
      circle.setAttribute("r", "8");
      circle.setAttribute("fill", KIND_FILL[node.kind]);
      const text = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "text"
      );
      text.setAttribute("x", String(p.x));
      text.setAttribute("y", String(p.y - 12));
      text.setAttribute("text-anchor", "middle");
      text.setAttribute("class", "text-xs fill-current");
      text.textContent = node.title;
      link.appendChild(circle);
      link.appendChild(text);
      g.appendChild(link);
      svg.appendChild(g);
    }
  }, [nodes, edges]);

  return (
    <svg
      ref={svgRef}
      class="w-full h-[440px] text-slate-700 dark:text-slate-300"
      role="img"
      aria-label="Affinity graph of AI envs and packages"
    />
  );
}
