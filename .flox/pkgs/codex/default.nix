{
  lib,
  stdenv,
  stdenvNoCC,
  cacert,
  cargo,
  fetchFromGitHub,
  fetchurl,
  fetchzip,
  gitMinimal,
  installShellFiles,
  makeWrapper,
  nix-prefetch-git,
  python3Packages,
  runCommand,
  rustPlatform,
  writers,
  pkg-config,
  openssl,
  bubblewrap,
  libcap,
  versionCheckHook,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash cargoHash;

  # Upstream rustPlatform.fetchCargoVendor invokes a Python helper that hits
  # crates.io with up to 5 parallel workers and only retries on 5xx. crates.io
  # has started returning 403 on concurrent bursts from a single egress IP,
  # which the upstream retry policy can't recover from — the build aborts on
  # the first 403. See PR #1635 CI logs.
  #
  # Until nixpkgs ships a fix, use a locally-patched copy of the helper that:
  #   * retries on 403 / 429 with a short linear backoff
  #   * lowers concurrency from 5 → 2 to stop triggering the limit
  #
  # Everything else mirrors the upstream fetchCargoVendor plumbing exactly.
  fetchCargoVendorUtil = writers.writePython3Bin "fetch-cargo-vendor-util" {
    libraries =
      with python3Packages;
      [
        requests
        tomli-w
      ]
      ++ requests.optional-dependencies.socks;
    flakeIgnore = [ "E501" ];
  } (builtins.readFile ./fetch-cargo-vendor-util.py);

  replaceWorkspaceValues = writers.writePython3Bin "replace-workspace-values" {
    libraries = with python3Packages; [
      tomli
      tomli-w
    ];
    flakeIgnore = [
      "E501"
      "W503"
    ];
  } (builtins.readFile ./replace-workspace-values.py);

  fetchCargoVendor =
    {
      name,
      src,
      sourceRoot ? "",
      hash,
      nativeBuildInputs ? [ ],
      ...
    }@args:
    let
      removedArgs = [
        "name"
        "pname"
        "version"
        "nativeBuildInputs"
        "hash"
      ];
      vendorStaging = stdenvNoCC.mkDerivation (
        {
          name = "${name}-vendor-staging";
          impureEnvVars = lib.fetchers.proxyImpureEnvVars;
          nativeBuildInputs = [
            fetchCargoVendorUtil
            cacert
            (nix-prefetch-git.override {
              git = gitMinimal;
              git-lfs = null;
            })
          ]
          ++ nativeBuildInputs;
          buildPhase = ''
            runHook preBuild
            if [ -n "''${cargoRoot-}" ]; then
              cd "$cargoRoot"
            fi
            fetch-cargo-vendor-util create-vendor-staging ./Cargo.lock "$out"
            runHook postBuild
          '';
          strictDeps = true;
          dontConfigure = true;
          dontInstall = true;
          dontFixup = true;
          outputHash = hash;
          outputHashAlgo = if hash == "" then "sha256" else null;
          outputHashMode = "recursive";
        }
        // removeAttrs args removedArgs
      );
    in
    runCommand "${name}-vendor"
      {
        inherit vendorStaging;
        nativeBuildInputs = [
          fetchCargoVendorUtil
          cargo
          replaceWorkspaceValues
        ];
      }
      ''
        fetch-cargo-vendor-util create-vendor "$vendorStaging" "$out"
      '';

  # The v8 crate downloads a prebuilt static library at build time.
  # Fetch it as a fixed-output derivation so the build stays sandboxed.
  librusty_v8 = fetchurl {
    name = "librusty_v8-${versionData.librusty_v8.version}";
    url = "https://github.com/denoland/rusty_v8/releases/download/v${versionData.librusty_v8.version}/librusty_v8_release_${stdenv.hostPlatform.rust.rustcTarget}.a.gz";
    hash = versionData.librusty_v8.hashes.${stdenv.hostPlatform.system};
    meta.sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };

  # codex-realtime-webrtc pulls in livekit's webrtc-sys on macOS,
  # whose build.rs would download a ~300MB prebuilt libwebrtc archive
  # at build time. Prefetch it as a fixed-output derivation and point
  # the crate at it via LK_CUSTOM_WEBRTC so the build stays sandboxed.
  livekitWebrtcTriple =
    {
      x86_64-darwin = "mac-x64";
      aarch64-darwin = "mac-arm64";
    }
    .${stdenv.hostPlatform.system} or null;
  livekitWebrtc =
    if livekitWebrtcTriple == null then
      null
    else
      fetchzip {
        name = "livekit-webrtc-${versionData.livekit_webrtc.tag}-${livekitWebrtcTriple}";
        url = "https://github.com/livekit/rust-sdks/releases/download/${versionData.livekit_webrtc.tag}/webrtc-${livekitWebrtcTriple}-release.zip";
        hash = versionData.livekit_webrtc.hashes.${stdenv.hostPlatform.system};
        meta.sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      };

  src = fetchFromGitHub {
    owner = "openai";
    repo = "codex";
    tag = "rust-v${version}";
    inherit hash;
  };

  cargoDeps = fetchCargoVendor {
    name = "codex-${version}";
    inherit src;
    sourceRoot = "source/codex-rs";
    hash = cargoHash;
  };
in
rustPlatform.buildRustPackage {
  pname = "codex";
  inherit version src cargoDeps;

  sourceRoot = "source/codex-rs";

  cargoBuildFlags = [
    "--package"
    "codex-cli"
  ];

  nativeBuildInputs = [
    installShellFiles
    makeWrapper
    pkg-config
  ];

  buildInputs =
    [ openssl ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ libcap ];

  env = {
    RUSTY_V8_ARCHIVE = librusty_v8;
  }
  // lib.optionalAttrs (livekitWebrtc != null) {
    LK_CUSTOM_WEBRTC = livekitWebrtc;
  };

  preBuild = ''
    # Remove LTO to speed up builds
    substituteInPlace Cargo.toml \
      --replace-fail 'lto = "fat"' 'lto = false'
  '';

  postFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram $out/bin/codex \
      --prefix PATH : ${lib.makeBinPath [ bubblewrap ]}
  '';

  doCheck = false;

  postInstall = ''
    installShellCompletion --cmd codex \
      --bash <($out/bin/codex completion bash) \
      --fish <($out/bin/codex completion fish) \
      --zsh <($out/bin/codex completion zsh)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "OpenAI Codex CLI - a coding agent that runs locally";
    homepage = "https://github.com/openai/codex";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = lib.platforms.unix;
  };
}
