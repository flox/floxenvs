{
  lib,
  buildNpmPackage,
  fetchurl,
  jq,
  runCommand,
  makeWrapper,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version sourceHash npmDepsHash;

  # The npm-published tarball does not ship package-lock.json (npm strips
  # it on publish). Inject a pinned lockfile into the source so
  # buildNpmPackage can resolve dependencies deterministically.
  srcWithLock = runCommand "skill-tools-src-with-lock" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/skill-tools/-/skill-tools-${version}.tgz";
        hash = sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json

    # The committed package-lock.json describes runtime dependencies
    # only (see upgrade.sh): `npm install --package-lock-only` records
    # devDependencies no matter what --omit=dev says, and Dependabot
    # then alerts on test runners and bundlers that dontNpmBuild means
    # we never run. `npm ci` refuses to run when package.json and
    # package-lock.json disagree, so the same field is deleted here.
    # nixpkgs' npmInstallHook prunes dev dependencies from the output
    # regardless, so nothing that used to ship stops shipping.
    jq 'del(.devDependencies)' $out/package.json > package.json.pruned
    rm -f $out/package.json
    mv package.json.pruned $out/package.json
  '';
in
buildNpmPackage {
  pname = "skill-tools";
  inherit version npmDepsHash;

  src = srcWithLock;

  # Tarball from npm ships prebuilt JS in dist/ already.
  dontNpmBuild = true;

  # npmInstallHook enumerates the files to install with `npm pack
  # --dry-run`, which runs the `prepare` lifecycle script. Upstream
  # packages commonly set `"prepare": "husky"` — a devDependency the
  # pruned lockfile no longer installs, and one this build has no use
  # for, since dontNpmBuild means nothing is built from source here.
  # Skipping pack's scripts keeps that from breaking the install phase.
  npmPackFlags = [ "--ignore-scripts" ];
  makeCacheWritable = true;

  nativeBuildInputs = [ makeWrapper ];

  # The published dist/cli.js hardcodes `program.version("0.2.2")` (the bundled
  # @skill-tools/core version), not the package version. `skill-tools --version`
  # therefore prints 0.2.2 regardless of the npm release, so versionCheckHook
  # cannot match the package version. Skip the version check; the build still
  # smoke-tests the binary below.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/skill-tools --help >/dev/null
    $out/bin/skill-tools score --help >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "CLI to score, validate, lint, and route Claude Agent Skills (SKILL.md)";
    homepage = "https://github.com/skill-tools/skill-tools";
    changelog = "https://github.com/skill-tools/skill-tools/releases";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "skill-tools";
    platforms = lib.platforms.unix;
  };
}
