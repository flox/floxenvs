export interface EnvForDerive {
  name: string;
  bundles_pkgs: string[];
  manifest_install: { name: string; path: string }[];
}

export interface PkgForDerive {
  name: string;
}

export interface DerivedEnv extends EnvForDerive {
  bundles_pkgs: string[];
}

export interface DerivedPkg extends PkgForDerive {
  bundled_by: string[];
}

export interface DeriveResult {
  envs: DerivedEnv[];
  pkgs: DerivedPkg[];
}

export function deriveBundling(
  envs: EnvForDerive[],
  pkgs: PkgForDerive[],
): DeriveResult {
  const knownPkgs = new Set(pkgs.map(p => p.name));

  const derivedEnvs: DerivedEnv[] = envs.map(env => {
    if (env.bundles_pkgs.length > 0) {
      return { ...env, bundles_pkgs: [...env.bundles_pkgs] };
    }
    const auto = env.manifest_install
      .map(i => i.name)
      .filter(n => knownPkgs.has(n));
    return { ...env, bundles_pkgs: auto };
  });

  const reverseLookup = new Map<string, string[]>();
  for (const env of derivedEnvs) {
    for (const pkg of env.bundles_pkgs) {
      const list = reverseLookup.get(pkg) ?? [];
      list.push(env.name);
      reverseLookup.set(pkg, list);
    }
  }

  const derivedPkgs: DerivedPkg[] = pkgs.map(p => ({
    ...p,
    bundled_by: reverseLookup.get(p.name) ?? [],
  }));

  return { envs: derivedEnvs, pkgs: derivedPkgs };
}
