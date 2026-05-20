{
  lib,
  stdenv,
  buildNpmPackage,
  fetchzip,
  makeWrapper,
  nodejs,
  runCommand,
  bubblewrap,
  socat,
  ripgrep,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash npmDepsHash;

  # The npmjs tarball doesn't ship package-lock.json (npm strips it on
  # publish), so inject a vendored lockfile into the source before
  # buildNpmPackage walks it.
  src = runCommand "sandbox-runtime-src-with-lock" { } ''
    mkdir -p $out
    cp -r ${
      fetchzip {
        url =
          "https://registry.npmjs.org/@anthropic-ai/sandbox-runtime/" + "-/sandbox-runtime-${version}.tgz";
        inherit hash;
      }
    }/* $out/
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
buildNpmPackage {
  npmDepsFetcherVersion = 2;
  inherit nodejs;
  pname = "sandbox-runtime";
  inherit version src npmDepsHash;
  makeCacheWritable = true;

  nativeBuildInputs = [ makeWrapper ];

  # The published tarball is prebuilt; we only need to install + wrap.
  dontNpmBuild = true;

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    # On Linux, suffix bubblewrap to PATH (not prefix) so a system bwrap
    # is preferred when present (Ubuntu ships specialized apparmor
    # policies). socat and ripgrep are hard requirements.
    wrapProgram $out/bin/srt \
      --suffix PATH : ${
        lib.makeBinPath [
          bubblewrap
          socat
          ripgrep
        ]
      }
  '';

  # The CLI prints the version from `commander`, not package.json, so
  # versionCheckHook can't match. Skip the install-check.
  doInstallCheck = false;

  meta = {
    description = "Anthropic's lightweight FS+network sandbox for agents (srt)";
    homepage = "https://github.com/anthropic-experimental/sandbox-runtime";
    changelog = "https://github.com/anthropic-experimental/sandbox-runtime/releases";
    downloadPage = "https://www.npmjs.com/package/@anthropic-ai/sandbox-runtime";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.unix;
    mainProgram = "srt";
  };
}
