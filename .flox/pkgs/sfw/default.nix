{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
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

  # The release binary is a Node single-executable app: the sfw program
  # is injected into a node binary as an ELF note. On Linux it must not
  # be rewritten by patchelf. Setting its RPATH (as autoPatchelfHook
  # does) corrupts it with patchelf 0.19, and the patched binary
  # segfaults on startup. Instead the binary is installed unmodified
  # and bin/sfw runs it through the glibc loader with --library-path.
  # Unlike LD_LIBRARY_PATH, --library-path applies to this process
  # only, so the package managers sfw launches don't inherit
  # nixpkgs' libstdc++.
  dontPatchELF = stdenv.hostPlatform.isLinux;

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

  ''
  + (
    if stdenv.hostPlatform.isLinux then
      ''
        install -Dm755 $src $out/libexec/sfw/sfw
        makeWrapper "$(cat $NIX_CC/nix-support/dynamic-linker)" $out/bin/sfw \
          --add-flags "--library-path ${
            lib.makeLibraryPath [
              gcc-unwrapped.lib
              (gcc-unwrapped.libgcc or null)
            ]
          }" \
          --add-flags "--argv0 sfw" \
          --add-flags "$out/libexec/sfw/sfw"
      ''
    else
      ''
        install -Dm755 $src $out/bin/sfw
      ''
  )
  + ''

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
      "x86_64-linux"
    ];
    mainProgram = "sfw";
  };
}
