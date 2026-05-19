{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  darwin,
  versionCheckHook,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "linux-x86_64";
    aarch64-linux = "linux-aarch64";
    x86_64-darwin = "macos-x86_64";
    aarch64-darwin = "macos-aarch64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform}
    or (throw "Unsupported system: ${platform}");

  src = fetchurl {
    url = "https://github.com/ogulcancelik/herdr/releases/download/v${version}/herdr-${platformSuffix}";
    hash = hashes.${platform};
  };
in
stdenvNoCC.mkDerivation {
  pname = "herdr";
  inherit version src;

  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;
  dontStrip = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    darwin.autoSignDarwinBinariesHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/herdr

    # Disable the upstream background update check by
    # redirecting its manifest URL to 127.0.0.1, where
    # the TCP connect is refused instantly. Replacement
    # is exactly 29 bytes (same as the original), so
    # all string-slice offsets and code refs stay
    # intact — only the bytes at the URL site change.
    # Idempotent: if upstream changes the URL, sed
    # matches nothing and the badge returns instead of
    # breaking the build.
    #
    # Tracked upstream: PR proposing an
    # HERDR_DISABLE_UPDATE_CHECK env-var gate. Once
    # merged, drop this patch and just set the env var
    # in the env manifest — the binary is then
    # untouched and this whole step disappears.
    sed -i \
      's|https://herdr.dev/latest.json|https://127.0.0.1/latest.json|g' \
      $out/bin/herdr

    # Patching invalidates the upstream adhoc signature;
    # macOS refuses to load Mach-O binaries with a stale
    # signature (SIGKILL at exec time). The
    # `autoSignDarwinBinariesHook` in nativeBuildInputs
    # re-signs adhoc during fixupPhase so the codesign
    # hash matches the patched bytes.

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
  ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "Agent multiplexer that lives in your terminal";
    homepage = "https://github.com/ogulcancelik/herdr";
    changelog = "https://github.com/ogulcancelik/herdr/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    mainProgram = "herdr";
  };
}
