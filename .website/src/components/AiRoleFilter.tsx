import { useState } from "preact/hooks";
import { AI_ROLES, type AiRole } from "../lib/kindNames";

const LABELS: Record<AiRole | "all", string> = {
  all: "All",
  agent: "Agent",
  "llm-runtime": "LLM runtime",
  rag: "RAG",
  orchestrator: "Orchestrator",
  tooling: "Tooling",
  ide: "IDE",
};

export default function AiRoleFilter() {
  const [active, setActive] = useState<"all" | AiRole>("all");

  const select = (role: "all" | AiRole) => {
    setActive(role);
    const cards = document.querySelectorAll<HTMLElement>("[data-ai-role]");
    for (const card of cards) {
      const cardRole = card.getAttribute("data-ai-role");
      card.toggleAttribute(
        "hidden",
        role !== "all" && cardRole !== role,
      );
    }
  };

  const roles: ("all" | AiRole)[] = ["all", ...AI_ROLES];
  return (
    <div class="flex flex-wrap gap-2">
      {roles.map((r) => (
        <button
          type="button"
          onClick={() => select(r)}
          aria-pressed={active === r}
          class={[
            "px-3 py-1.5 rounded-full text-sm font-medium border transition",
            active === r
              ? "bg-slate-900 text-white border-slate-900 dark:bg-slate-100 dark:text-slate-900 dark:border-slate-100"
              : "border-slate-300 text-slate-700 hover:border-slate-500 dark:border-slate-700 dark:text-slate-300",
          ].join(" ")}
        >
          {LABELS[r]}
        </button>
      ))}
    </div>
  );
}
