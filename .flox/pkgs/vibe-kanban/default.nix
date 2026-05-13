{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  unzip,
  makeWrapper,
  git,
  nodejs_20,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version binaryTag binaries;

  platformMap = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "macos-x64";
    aarch64-darwin = "macos-arm64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform}
    or (throw "Unsupported system: ${platform}");

  baseUrl = "https://npm-cdn.vibekanban.com/binaries/${binaryTag}";

  fetchBinary = name: fetchurl {
    url = "${baseUrl}/${platformSuffix}/${name}.zip";
    hash = binaries.${name}.${platform};
  };

  vibeKanbanSrc = fetchBinary "vibe-kanban";
  vibeKanbanMcpSrc = fetchBinary "vibe-kanban-mcp";
  vibeKanbanReviewSrc = fetchBinary "vibe-kanban-review";
in
stdenvNoCC.mkDerivation {
  pname = "vibe-kanban";
  inherit version;

  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;

  nativeBuildInputs = [
    makeWrapper
    unzip
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    unzip -p ${vibeKanbanSrc} vibe-kanban > $out/bin/vibe-kanban
    unzip -p ${vibeKanbanMcpSrc} vibe-kanban-mcp \
      > $out/bin/vibe-kanban-mcp
    unzip -p ${vibeKanbanReviewSrc} vibe-kanban-review \
      > $out/bin/vibe-kanban-review
    chmod +x $out/bin/vibe-kanban \
      $out/bin/vibe-kanban-mcp \
      $out/bin/vibe-kanban-review

    runHook postInstall
  '';

  # vibe-kanban spawns git and coding-agent subprocesses. git and
  # node are the baseline dependencies; coding agents (claude,
  # codex, gemini, ...) are pulled in by the consuming env.
  postFixup = ''
    for prog in vibe-kanban vibe-kanban-mcp vibe-kanban-review; do
      wrapProgram $out/bin/$prog \
        --prefix PATH : ${
          lib.makeBinPath [
            git
            nodejs_20
          ]
        }
    done
  '';

  # vibe-kanban has no --version or --help; running it starts the
  # server and listens forever. Skip versionCheckHook and rely on
  # the env's test.sh to validate the binary works.

  meta = {
    description = "Kanban-style task manager for coding agents";
    homepage = "https://github.com/BloopAI/vibe-kanban";
    changelog = "https://github.com/BloopAI/vibe-kanban/releases/tag/${binaryTag}";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    mainProgram = "vibe-kanban";
  };
}
