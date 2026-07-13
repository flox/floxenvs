import type { WizardItem } from "./wizardItems";

// A TOML bare key: letters, digits, underscores, hyphens. The install
// id is the last path segment of the pkg-path, sanitized.
function installKey(item: WizardItem): string {
  const base = item.installPkg.split("/").pop() ?? item.id;
  return base.replace(/[^A-Za-z0-9_-]/g, "-");
}

export function buildManifest(items: WizardItem[]): string {
  const lines = ["[install]"];
  for (const it of items) {
    lines.push(`${installKey(it)}.pkg-path = "${it.installPkg}"`);
  }
  return lines.join("\n") + "\n";
}

export function buildInstallCommands(items: WizardItem[]): string {
  return items.map((it) => `flox install ${it.installPkg}`).join("\n");
}
