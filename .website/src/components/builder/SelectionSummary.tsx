import type { WizardItem } from "../../lib/wizardItems";

export default function SelectionSummary({ items }: { items: WizardItem[] }) {
  return (
    <div class="hairline border-t pt-2 mt-4 text-sm">
      <p class="text-[var(--builder-muted)]">your env so far</p>
      {items.length === 0 ? (
        <p class="text-[var(--builder-muted)]">nothing selected yet</p>
      ) : (
        <ul class="flex flex-wrap gap-x-3">
          {items.map((it) => (
            <li key={it.id} class="accent">
              {it.installPkg}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
