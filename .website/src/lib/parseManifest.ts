import { parse as parseToml } from "smol-toml";

export interface InstalledPkg {
  name: string;
  path: string;
}

export function parseInstalledPackages(toml: string): InstalledPkg[] {
  let parsed: Record<string, unknown>;
  try {
    parsed = parseToml(toml) as Record<string, unknown>;
  } catch {
    return [];
  }
  const install = parsed.install as Record<string, unknown> | undefined;
  if (!install || typeof install !== "object") return [];

  const pkgs: InstalledPkg[] = [];
  for (const [name, value] of Object.entries(install)) {
    if (!value || typeof value !== "object") continue;
    const path = (value as Record<string, unknown>)["pkg-path"];
    if (typeof path === "string") {
      pkgs.push({ name, path });
    }
  }
  return pkgs;
}
