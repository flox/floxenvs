{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  coreutils,
  autoPatchelfHook,
  zlib,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "linux/x64";
    aarch64-linux = "linux/arm64";
    x86_64-darwin = "darwin/x64";
    aarch64-darwin = "darwin/arm64";
  };

  platform = stdenv.hostPlatform.system;
  platformPath = platformMap.${platform} or (throw "Unsupported system: ${platform}");

  src = fetchurl {
    url = "https://downloads.cursor.com/lab/${version}" + "/${platformPath}/agent-cli-package.tar.gz";
    hash = hashes.${platform};
  };
in
stdenv.mkDerivation {
  pname = "cursor-agent";
  inherit version src;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
    zlib
  ];

  unpackPhase = ''
    runHook preUnpack
    tar -xzf $src
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    cp -r dist-package/* $out/

    chmod +x $out/cursor-agent
    chmod +x $out/node
    chmod +x $out/rg

    mkdir -p $out/bin
    makeWrapper $out/cursor-agent $out/bin/cursor-agent \
      --prefix PATH : $out \
      --prefix PATH : ${coreutils}/bin

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "CLI tool for Cursor AI code editor";
    homepage = "https://cursor.com/";
    changelog = "https://www.cursor.com/changelog";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [
      binaryNativeCode
    ];
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    mainProgram = "cursor-agent";
  };
}
