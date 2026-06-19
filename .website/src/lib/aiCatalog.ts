// Maps flox/.flox/pkgs meta.yaml package entries (as loaded into the
// `packages` content collection) into the ai-catalog.json schema the
// flox-ai TUI consumes. Only Claude Code fragment packages are
// included; `subkind: plain` packages (and envs) are excluded.

export const FRAGMENT_SUBKINDS = ["plugin", "skill", "agent", "rule"] as const;
export type FragmentSubkind = (typeof FRAGMENT_SUBKINDS)[number];

export interface PkgData {
  name: string;
  title: string;
  subkind: string;
  plugin_for?: string | null;
  skill_for?: string | null;
  tagline: string;
  tags?: string[];
  category: string;
  featured?: boolean;
  links?: Record<string, string>;
  install?: { pkg?: string };
  intro?: string;
  summary?: string[];
  stack?: string[];
  license?: string;
  maintainer?: string;
}

export interface CatalogItem {
  id: string;
  name: string;
  type: FragmentSubkind;
  for: string;
  description: string;
  tags: string[];
  categories: string[];
  featured: boolean;
  link: string;
  homepage?: string;
  installPkg: string;
  intro?: string;
  summary?: string[];
  stack?: string[];
  license?: string;
  maintainer?: string;
}

export function isFragmentPkg(p: PkgData): boolean {
  return (FRAGMENT_SUBKINDS as readonly string[]).includes(p.subkind);
}

// Extract the package's own pkg-path from the install.pkg TOML block.
// The block lists the claude-code dependency plus the fragment itself;
// we want the line keyed by the package name, e.g.
//   claude-code-plugin-caveman.pkg-path = "flox/claude-code-plugin-caveman"
export function extractInstallPkg(p: PkgData): string {
  const block = p.install?.pkg ?? "";
  const re = new RegExp(
    `^\\s*${escapeRe(p.name)}\\.pkg-path\\s*=\\s*"([^"]+)"`,
    "m",
  );
  const m = block.match(re);
  return m ? m[1] : `flox/${p.name}`;
}

function escapeRe(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

export function toCatalogItem(p: PkgData): CatalogItem {
  return {
    id: p.name,
    name: p.title,
    // Precondition: callers filter with isFragmentPkg first, so subkind
    // is always a valid FragmentSubkind here.
    type: p.subkind as FragmentSubkind,
    for: p.plugin_for ?? p.skill_for ?? "",
    description: (p.tagline ?? "").trim(),
    tags: p.tags ?? [],
    categories: p.category ? [p.category] : [],
    featured: p.featured ?? false,
    link: p.links?.source ?? p.links?.floxhub ?? "",
    ...(p.links?.homepage ?? p.links?.website ?? p.links?.docs
      ? { homepage: p.links?.homepage ?? p.links?.website ?? p.links?.docs }
      : {}),
    installPkg: extractInstallPkg(p),
    ...(p.intro ? { intro: p.intro } : {}),
    ...(p.summary && p.summary.length ? { summary: p.summary } : {}),
    ...(p.stack && p.stack.length ? { stack: p.stack } : {}),
    ...(p.license ? { license: p.license } : {}),
    ...(p.maintainer ? { maintainer: p.maintainer } : {}),
  };
}

// featured first, then name A→Z.
export function rankItems(items: CatalogItem[]): CatalogItem[] {
  return [...items].sort((a, b) => {
    if (a.featured !== b.featured) return a.featured ? -1 : 1;
    return a.name.localeCompare(b.name);
  });
}

export function buildCatalog(pkgs: PkgData[]): CatalogItem[] {
  return rankItems(pkgs.filter(isFragmentPkg).map(toCatalogItem));
}
