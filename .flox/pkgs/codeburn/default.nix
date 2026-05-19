{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
  makeWrapper,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version sourceHash npmDepsHash;

  # The npm-published tarball does not ship package-lock.json (npm strips
  # it on publish). Inject a pinned lockfile into the source so
  # buildNpmPackage can resolve dependencies deterministically.
  srcWithLock = runCommand "codeburn-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/codeburn/-/codeburn-${version}.tgz";
        hash = sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "codeburn";
  inherit version npmDepsHash;

  src = srcWithLock;

  # Tarball from npm ships prebuilt JS in dist/ already.
  dontNpmBuild = true;
  makeCacheWritable = true;

  nativeBuildInputs = [ makeWrapper ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "TUI dashboard for AI coding token usage and cost observability";
    homepage = "https://github.com/getagentseal/codeburn";
    changelog = "https://github.com/getagentseal/codeburn/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "codeburn";
    platforms = lib.platforms.unix;
  };
}
