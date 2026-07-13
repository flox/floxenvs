// .website/src/components/builder/OutputPane.tsx
import type { WizardItem } from "../../lib/wizardItems";
import { buildManifest, buildInstallCommands } from "../../lib/buildSnippet";

export default function OutputPane({ items }: { items: WizardItem[] }) {
  const manifest = buildManifest(items);
  const commands = buildInstallCommands(items);
  const copy = (text: string) => {
    void navigator.clipboard?.writeText(text);
  };
  return (
    <div class="space-y-4">
      <div>
        <div class="flex items-center justify-between">
          <p class="text-[var(--builder-muted)] text-sm">manifest.toml</p>
          <button type="button" class="accent text-sm" onClick={() => copy(manifest)}>
            copy
          </button>
        </div>
        <pre class="hairline border p-3 overflow-x-auto text-sm">{manifest}</pre>
      </div>
      <div>
        <div class="flex items-center justify-between">
          <p class="text-[var(--builder-muted)] text-sm">or install directly</p>
          <button type="button" class="accent text-sm" onClick={() => copy(commands)}>
            copy
          </button>
        </div>
        <pre class="hairline border p-3 overflow-x-auto text-sm">
          {commands || "# select packages to see install commands"}
        </pre>
      </div>
      {/* FloxHub seam: API-backed create lands here later. */}
      <button
        type="button"
        disabled
        data-floxhub
        title="Coming soon: create this environment on FloxHub"
        class="hairline border px-3 py-2 text-sm opacity-50 cursor-not-allowed"
      >
        Create on FloxHub (soon)
      </button>
    </div>
  );
}
