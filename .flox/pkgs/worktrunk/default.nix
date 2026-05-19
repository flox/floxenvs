{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  git,
  versionCheckHook,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "x86_64-unknown-linux-musl";
    aarch64-linux = "aarch64-unknown-linux-musl";
    x86_64-darwin = "x86_64-apple-darwin";
    aarch64-darwin = "aarch64-apple-darwin";
  };

  platform = stdenv.hostPlatform.system;
  triple = platformMap.${platform}
    or (throw "Unsupported system: ${platform}");

  src = fetchurl {
    url = "https://github.com/max-sixty/worktrunk/releases/download/v${version}/worktrunk-${triple}.tar.xz";
    hash = hashes.${platform};
  };
in
stdenvNoCC.mkDerivation {
  pname = "worktrunk";
  inherit version src;

  sourceRoot = "worktrunk-${triple}";

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 wt $out/bin/wt
    install -Dm755 git-wt $out/bin/git-wt
    install -Dm644 LICENSE $out/share/doc/worktrunk/LICENSE
    install -Dm644 README.md $out/share/doc/worktrunk/README.md
    install -Dm644 CHANGELOG.md $out/share/doc/worktrunk/CHANGELOG.md

    runHook postInstall
  '';

  # worktrunk shells out to git for every worktree operation, so
  # keep it on PATH regardless of what the consuming env provides.
  postFixup = ''
    for prog in wt git-wt; do
      wrapProgram $out/bin/$prog \
        --prefix PATH : ${lib.makeBinPath [ git ]}
    done
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "CLI for git worktree management, designed for parallel AI agent workflows";
    homepage = "https://worktrunk.dev";
    changelog = "https://github.com/max-sixty/worktrunk/releases/tag/v${version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    mainProgram = "wt";
  };
}
