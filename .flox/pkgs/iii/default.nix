{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  gcc-unwrapped,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    aarch64-darwin = "aarch64-apple-darwin";
    aarch64-linux = "aarch64-unknown-linux-gnu";
    x86_64-linux = "x86_64-unknown-linux-gnu";
  };

  platform = stdenv.hostPlatform.system;
  target = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "iii";
  inherit version;

  src = fetchurl {
    url =
      "https://github.com/iii-hq/iii/releases/download/"
      + "iii/v${version}/iii-${target}.tar.gz";
    hash = hashes.${platform};
  };

  # The tarball holds the bare `iii` binary at its root.
  sourceRoot = ".";

  # The upstream Linux builds are glibc binaries with a hardcoded
  # /lib64 interpreter, which doesn't exist on NixOS or in Flox
  # containers.
  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    gcc-unwrapped.lib
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 iii $out/bin/iii

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "iii engine, the runtime the agentmemory server runs on";
    homepage = "https://iii.dev";
    changelog = "https://github.com/iii-hq/iii/releases/tag/iii/v${version}";
    license = with lib.licenses; [
      asl20
      elastic20
    ];
    sourceProvenance = with lib.sourceTypes; [
      binaryNativeCode
    ];
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    mainProgram = "iii";
  };
}
