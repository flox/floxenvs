{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  cacert,
  nodejs_24,
  ripgrep,
  bash,
  glib,
  libsecret,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "copilot-cli";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@github/copilot/-/copilot-${version}.tgz";
    hash = srcHash;
  };

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [
    # keytar.node — credential storage via libsecret
    libsecret
    glib
  ];

  # Bundled mxc-bin/{x64,arm64}/lxc-exec dlopen libgcc_s.so.1 at runtime.
  runtimeDependencies = lib.optionals stdenv.hostPlatform.isLinux [
    stdenv.cc.cc.lib
  ];

  # Skip dependencies that come from two upstream-bundled file groups we
  # don't expect to use on a Nix glibc system:
  #   - prebuilds/linux-*/computer.node is a screen-capture / desktop-
  #     automation native module (X11, libXtst, libpipewire, libei,
  #     libjpeg, libpng). The CLI loads it lazily so let the build pass
  #     and let those features fail at runtime, not at build.
  #   - prebuilds/linuxmusl-*/keytar.node and runtime.node are Alpine-style
  #     musl variants; they're not loaded on glibc, but autoPatchelfHook
  #     still processes any file matching the target arch and aborts on
  #     libc.musl. Ignoring the symbol is simpler than deleting the files.
  autoPatchelfIgnoreMissingDeps = lib.optionals stdenv.hostPlatform.isLinux [
    "libX11.so.6"
    "libXtst.so.6"
    "libjpeg.so.8"
    "libpng16.so.16"
    "libgio-2.0.so.0"
    "libgobject-2.0.so.0"
    "libpipewire-0.3.so.0"
    "libei.so.1"
    "libc.musl-x86_64.so.1"
    "libc.musl-aarch64.so.1"
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/${finalAttrs.pname}
    cp -r . $out/lib/${finalAttrs.pname}

    mkdir -p $out/bin
    makeWrapper ${nodejs_24}/bin/node $out/bin/copilot \
      --add-flags "$out/lib/${finalAttrs.pname}/index.js" \
      --set SSL_CERT_DIR "${cacert}/etc/ssl/certs" \
      --set-default COPILOT_AUTO_UPDATE false \
      --set-default USE_BUILTIN_RIPGREP false \
      --prefix PATH : ${
        lib.makeBinPath [
          ripgrep
          bash
        ]
      }

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "GitHub Copilot CLI - Copilot coding agent in your terminal";
    homepage = "https://github.com/github/copilot-cli";
    changelog = "https://github.com/github/copilot-cli/releases/tag/v${version}";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode
    ];
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    mainProgram = "copilot";
  };
})
