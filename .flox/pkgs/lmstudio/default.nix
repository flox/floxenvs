{
  lib,
  stdenv,
  callPackage,
}:
let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  upstreamVersion = versionData.version;
  version = "${upstreamVersion}+flox";

  meta = {
    description = "LM Studio - Desktop app for experimenting with local and open-source LLMs";
    homepage = "https://lmstudio.ai/";
    license = lib.licenses.unfree;
    mainProgram = "lm-studio";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];
  };

  # LM Studio has no x86_64-darwin build, so that platform is
  # deliberately absent from hashes.json and will hit this throw.
  currentSource =
    versionData.sources.${stdenv.hostPlatform.system}
      or (throw "lmstudio: unsupported system: ${stdenv.hostPlatform.system}");
in
if stdenv.hostPlatform.isDarwin then
  callPackage ./darwin.nix {
    inherit meta version;
    inherit (currentSource) url hash;
  }
else
  callPackage ./linux.nix {
    inherit meta version;
    inherit (currentSource) url hash;
  }
