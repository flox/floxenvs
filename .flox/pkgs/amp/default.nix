{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  ripgrep,
  cctools,
  darwin,
  rcodesign,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version;
  hashes = versionData.binaryHashes;

  platformMap = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "amp";
  inherit version;

  src = fetchurl {
    url = "https://static.ampcode.com/cli/${version}/amp-${platformSuffix}";
    hash = hashes.${platform};
  };

  dontUnpack = true;
  # Do not mess with the bun runtime embedded in the binary.
  dontStrip = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    cctools
    rcodesign
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/amp

    runHook postInstall
  '';

  # Rewrite Bun's ICU dependency to Nix-provided darwin.ICU instead of
  # /usr/lib/libicucore.A.dylib, which needs /usr/share/icu/ at runtime.
  # This avoids __noChroot and lets the build run in the macOS sandbox.
  # Re-signing is required after the modification invalidates the signature.
  postFixup = ''
    ${lib.optionalString stdenv.hostPlatform.isDarwin ''
      ${lib.getExe' cctools "${cctools.targetPrefix}install_name_tool"} \
        $out/bin/amp \
        -change /usr/lib/libicucore.A.dylib \
        '${lib.getLib darwin.ICU}/lib/libicucore.A.dylib'
      ${lib.getExe rcodesign} sign \
        --code-signature-flags linker-signed $out/bin/amp
    ''}
    wrapProgram $out/bin/amp \
      --argv0 amp \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]} \
      --set AMP_SKIP_UPDATE_CHECK 1
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "CLI for Amp, Sourcegraph's agentic coding tool";
    homepage = "https://ampcode.com/";
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
    mainProgram = "amp";
  };
}
