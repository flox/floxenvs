{
  lib,
  buildNpmPackage,
  fetchurl,
  runCommand,
  makeWrapper,
  fd,
  ripgrep,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version sourceHash npmDepsHash;

  # The npm-published tarball does not ship package-lock.json (npm strips
  # it on publish). Inject a pinned lockfile into the source so
  # buildNpmPackage can resolve dependencies deterministically.
  srcWithLock = runCommand "pi-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@mariozechner/pi-coding-agent/-/pi-coding-agent-${version}.tgz";
        hash = sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  pname = "pi";
  inherit version npmDepsHash;

  src = srcWithLock;

  # Tarball from npm ships prebuilt JS in dist/ already.
  dontNpmBuild = true;
  makeCacheWritable = true;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/pi \
      --prefix PATH : ${
        lib.makeBinPath [
          fd
          ripgrep
        ]
      } \
      --set PI_SKIP_VERSION_CHECK 1 \
      --set PI_TELEMETRY 0
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Terminal-based coding agent with multi-model support";
    homepage = "https://github.com/badlogic/pi-mono";
    changelog = "https://github.com/badlogic/pi-mono/releases";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    mainProgram = "pi";
    platforms = lib.platforms.unix;
  };
}
