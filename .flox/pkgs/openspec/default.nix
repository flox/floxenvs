{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version sourceHash npmDepsHash;

  # The npmjs tarball doesn't ship package-lock.json (npm strips it on
  # publish), so inject a vendored lockfile before buildNpmPackage runs.
  srcWithLock = runCommand "openspec-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@fission-ai/openspec/" + "-/openspec-${version}.tgz";
        hash = sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  npmDepsFetcherVersion = 2;
  pname = "openspec";
  inherit version npmDepsHash;

  src = srcWithLock;
  makeCacheWritable = true;

  # The published tarball is prebuilt; we only install + wrap.
  dontNpmBuild = true;

  meta = {
    description = "Spec-driven development workflow for AI coding assistants";
    homepage = "https://github.com/Fission-AI/OpenSpec";
    changelog = "https://github.com/Fission-AI/OpenSpec/releases/tag/v${version}";
    downloadPage = "https://www.npmjs.com/package/@fission-ai/openspec";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    platforms = lib.platforms.all;
    mainProgram = "openspec";
  };
}
