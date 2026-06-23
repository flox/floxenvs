import type { WizardItem } from "../../lib/wizardItems";

function auditTone(status: string): string {
  if (status === "ok" || status === "stable") return "var(--color-score-green)";
  if (status === "risk") return "var(--color-score-red)";
  return "var(--builder-muted)";
}

export default function SelectionList({
  items,
  selectedIds,
  onToggle,
  showAudit = false,
}: {
  items: WizardItem[];
  selectedIds: string[];
  onToggle: (id: string) => void;
  showAudit?: boolean;
}) {
  if (!items.length) {
    return <p class="text-[var(--builder-muted)] text-sm py-4">No matches.</p>;
  }
  return (
    <ul class="divide-y hairline">
      {items.map((it) => {
        const on = selectedIds.includes(it.id);
        return (
          <li key={it.id}>
            <button
              type="button"
              onClick={() => onToggle(it.id)}
              aria-pressed={on}
              class="w-full flex items-center gap-3 py-2 text-left hover:bg-[var(--builder-surface)]"
            >
              <span class="accent w-4">{on ? "[x]" : "[ ]"}</span>
              <span class="flex-1">{it.name}</span>
              {showAudit && it.audit && (
                <span
                  class="font-mono text-sm"
                  style={{ color: auditTone(it.audit.status) }}
                  title={`audit: ${it.audit.status}`}
                >
                  {it.audit.overall}
                </span>
              )}
            </button>
          </li>
        );
      })}
    </ul>
  );
}
