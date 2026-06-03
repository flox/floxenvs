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
    aarch64-darwin = "sfw-free-macos-arm64";
    x86_64-darwin = "sfw-free-macos-x86_64";
    aarch64-linux = "sfw-free-linux-arm64";
    x86_64-linux = "sfw-free-linux-x86_64";
  };

  platform = stdenv.hostPlatform.system;
  asset = platformMap.${platform} or (throw "Unsupported system: ${platform}");
in
stdenv.mkDerivation {
  pname = "sfw";
  inherit version;

  src = fetchurl {
    url =
      "https://github.com/SocketDev/sfw-free/releases/download/"
      + "v${version}/${asset}";
    hash = hashes.${platform};
  };

  shims = ./shims;

  dontUnpack = true;
  # The release binary bundles a JS runtime; stripping can break it.
  dontStrip = true;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    gcc-unwrapped.lib
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/sfw

    # Per-ecosystem PATH shims. Consumers opt in by prepending
    # $FLOX_ENV/libexec/sfw-shims to their PATH (e.g. in [hook]
    # on-activate), which transparently routes each package-manager
    # call through `sfw` in interactive shells, scripts, sub-processes,
    # and CI alike.
    install -Dm755 $shims/sfw-shim $out/libexec/sfw-shims/sfw-shim
    for cmd in npm yarn pnpm pip uv cargo; do
      ln -s sfw-shim "$out/libexec/sfw-shims/$cmd"
    done

    # Sourceable helpers for [profile.bash] / [profile.zsh] that keep the
    # shim dir at the front of PATH even after a third-party activate
    # script (e.g. a Python venv) prepends its own bin.
    install -Dm644 $shims/activate.bash $out/libexec/sfw-shims/activate.bash
    install -Dm644 $shims/activate.zsh $out/libexec/sfw-shims/activate.zsh

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "Socket Firewall Free - wraps your package manager to prevent installation of malicious packages";
    homepage = "https://github.com/SocketDev/sfw-free";
    changelog = "https://github.com/SocketDev/sfw-free/releases/tag/v${version}";
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
    mainProgram = "sfw";
  };
}
