{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  cacert,
  cmake,
  pkg-config,
  openssl,
  libxcb,
  dbus,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash cargoHash;

  # The v8 crate downloads a prebuilt static library at build time.
  # Fetch it as a fixed-output derivation so the build stays sandboxed.
  librusty_v8 = fetchurl {
    name = "librusty_v8-${versionData.librusty_v8.version}";
    url =
      "https://github.com/denoland/rusty_v8/releases/download/"
      + "v${versionData.librusty_v8.version}/librusty_v8_release_"
      + "${stdenv.hostPlatform.rust.rustcTarget}.a.gz";
    hash = versionData.librusty_v8.hashes.${stdenv.hostPlatform.system};
    meta.sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
in
rustPlatform.buildRustPackage {
  pname = "goose-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "block";
    repo = "goose";
    tag = "v${version}";
    hash = srcHash;
  };

  inherit cargoHash;

  nativeBuildInputs = [
    cmake
    pkg-config
    rustPlatform.bindgenHook
  ];

  # cmake's nix hook sets CMAKE_BUILD_TYPE=Release which the
  # llama-cpp-sys-2 crate's build script overrides. Disable the hook so
  # the crate stays in control of its own cmake invocation.
  dontUseCmakeConfigure = true;

  buildInputs = [
    openssl
    libxcb
    dbus
  ];

  env.RUSTY_V8_ARCHIVE = librusty_v8;

  cargoBuildFlags = [
    "--package"
    "goose-cli"
  ];

  # Tests need writable XDG dirs and run only goose-cli's test target.
  # cacert provides the CA bundle for reqwest's TLS init (otherwise
  # tests that build an HTTP client panic with "No CA certificates
  # were loaded from the system" on Linux, where there's no system
  # trust store in the Nix sandbox).
  doCheck = true;
  nativeCheckInputs = [ cacert ];
  checkPhase = ''
    runHook preCheck

    export HOME=$(mktemp -d)
    export XDG_CONFIG_HOME=$HOME/.config
    export XDG_DATA_HOME=$HOME/.local/share
    export XDG_STATE_HOME=$HOME/.local/state
    export XDG_CACHE_HOME=$HOME/.cache
    mkdir -p \
      $XDG_CONFIG_HOME $XDG_DATA_HOME \
      $XDG_STATE_HOME $XDG_CACHE_HOME

    # Skip tests that require live network access (sigstore.dev for
    # SLSA provenance verification, langfuse for tracing). These
    # can't run in the Nix sandbox.
    cargo test --package goose-cli --release -- \
      --skip commands::update::tests::test_verify_provenance_warns_on_missing_attestation \
      --skip logging::tests::test_langfuse_layer_creation

    runHook postCheck
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Block's local, extensible, open source AI engineering agent";
    homepage = "https://github.com/block/goose";
    changelog = "https://github.com/block/goose/releases/tag/v${version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    platforms = lib.platforms.unix;
    mainProgram = "goose";
  };
}
