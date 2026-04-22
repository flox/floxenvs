{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  bubblewrap,
  procps,
  socat,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform}
    or (throw "Unsupported system: ${platform}");

  baseUrl = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

  src = fetchurl {
    url = "${baseUrl}/${version}/${platformSuffix}/claude";
    hash = hashes.${platform};
  };
in
stdenvNoCC.mkDerivation {
  pname = "claude-code";
  inherit version src;

  dontUnpack = true;
  dontBuild = true;
  dontConfigure = true;
  # Do not mess with the bun runtime embedded in the binary.
  dontStrip = true;

  # Bun links against /usr/lib/libicucore.A.dylib which needs ICU data from
  # /usr/share/icu/ at runtime for Intl.Segmenter. The Nix macOS sandbox
  # blocks access to /usr/share/icu/, causing "failed to initialize Segmenter".
  __noChroot = stdenv.hostPlatform.isDarwin;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/claude

    runHook postInstall
  '';

  # --argv0 preserves the process name so it shows as "claude" in ps/htop
  # rather than ".claude-wrapped".
  postFixup = ''
    wrapProgram $out/bin/claude \
      --argv0 claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --unset DEV \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            procps
          ]
          ++ lib.optionals stdenv.hostPlatform.isLinux [
            bubblewrap
            socat
          ]
        )
      }
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "Agentic coding tool from Anthropic";
    homepage = "https://github.com/anthropics/claude-code";
    downloadPage = "https://claude.com/product/claude-code";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    mainProgram = "claude";
  };
}
