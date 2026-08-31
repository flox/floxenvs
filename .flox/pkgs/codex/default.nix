{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  fetchzip,
  installShellFiles,
  makeWrapper,
  rustPlatform,
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

  # The v8 crate downloads a prebuilt static library and a matching generated
  # bindings file at build time. Fetch both as fixed-output derivations so the
  # build stays sandboxed.
  #
  # It must be the POINTER-COMPRESSION + SANDBOX variant: codex-code-mode-host
  # depends on codex-code-mode-runtime, which takes `v8` with the
  # `v8_enable_sandbox` feature, and cargo's feature resolution then builds the
  # whole v8 crate that way. denoland/rusty_v8 publishes no prebuilt artifacts
  # for that combination (its releases carry only the plain, ptrcomp and
  # simdutf variants), so upstream builds its own pair from source and
  # publishes it on the openai/codex release `rusty-v8-v<v8 crate version>`.
  # Upstream's own builds consume exactly these two files via
  # RUSTY_V8_ARCHIVE / RUSTY_V8_SRC_BINDING_PATH — see
  # .github/actions/setup-rusty-v8 in openai/codex.
  #
  # Do NOT "simplify" this back to denoland's plain `release` assets. Both
  # RUSTY_V8_* vars override rusty_v8's own feature-derived asset choice
  # (build.rs `static_lib_url`), so a plain archive + plain bindings still
  # link and still build — but the v8 crate's Rust half is compiled with
  # `v8_enable_sandbox` either way, and that feature gates real API surface
  # (`array_buffer.rs`, `shared_array_buffer.rs`) as well as V8's heap
  # layout. nixpkgs' codex derivation does exactly that; it silently ships a
  # V8 without the sandbox codex asked for. numtide/llm-agents.nix uses these
  # same openai-published artifacts, with pins identical to ours.
  #
  # `librusty_v8.version` is the v8 CRATE version pinned by codex-rs/Cargo.toml,
  # NOT the codex version; re-check it on every version bump (see upgrade.sh).
  # The block's key names match numtide's, and are a superset of the
  # `librusty_v8` block goose-cli keeps in this repo. The base URL is derived
  # from `version` rather than stored beside it (numtide stores one, but their
  # update.py regenerates the whole block, while our upgrade.sh preserves it
  # verbatim — a stored URL with the version inlined would silently desync).
  rustyV8 = versionData.librusty_v8;
  rustyV8BaseUrl = "https://github.com/openai/codex/releases/download/rusty-v8-v${rustyV8.version}";
  rustyV8Target = stdenv.hostPlatform.rust.rustcTarget;

  librusty_v8 = fetchurl {
    name = "librusty_v8-${rustyV8.profile}-${rustyV8.version}.a.gz";
    url = "${rustyV8BaseUrl}/librusty_v8_${rustyV8.profile}_${rustyV8Target}.a.gz";
    hash = rustyV8.hashes.${stdenv.hostPlatform.system};
    meta.sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };

  rustyV8SrcBinding = fetchurl {
    name = "src_binding-${rustyV8.profile}-${rustyV8.version}.rs";
    url = "${rustyV8BaseUrl}/src_binding_${rustyV8.profile}_${rustyV8Target}.rs";
    hash = rustyV8.srcBindingHashes.${stdenv.hostPlatform.system};
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
in
rustPlatform.buildRustPackage {
  pname = "codex";
  inherit version src;

  inherit cargoHash;

  sourceRoot = "source/codex-rs";

  # flox-fragments.patch teaches Codex to read two env vars set by
  # `flox-ai launch codex`: CODEX_FLOX_SKILL_ROOTS (extra skill-root dirs)
  # and CODEX_FLOX_INSTRUCTIONS_FILE (extra project instructions). This lets
  # flox inject environment-managed skills and rules without mutating
  # ~/.codex or the working tree. Re-verify on every version bump
  # (see upgrade.sh) — the patch targets ext/skills/src/host_roots.rs and
  # core/agents_md.rs. Paths are relative to codex-rs (the sourceRoot).
  patches = [ ./flox-fragments.patch ];

  # codex-cli alone leaves out the Code Mode host binary. Codex's Code Mode
  # spawns `codex-code-mode-host` (workspace member code-mode-host) as a child
  # process for tool execution, so omitting it makes every Code Mode tool call
  # fail with "failed to spawn code-mode host ...: No such file or directory".
  # Upstream ships it as its own release asset; build it as a package too.
  # nixpkgs (pkgs/by-name/co/codex) and numtide/llm-agents.nix both pass
  # exactly these two --package flags.
  cargoBuildFlags = [
    "--package"
    "codex-cli"
    "--package"
    "codex-code-mode-host"
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
    RUSTY_V8_SRC_BINDING_PATH = rustyV8SrcBinding;
  }
  // lib.optionalAttrs (livekitWebrtc != null) {
    LK_CUSTOM_WEBRTC = livekitWebrtc;
  };

  preBuild = ''
    # Remove LTO to speed up builds. Keep codegen-units = 1 from upstream:
    # raising it bloats the binary past the 128 MB ARM64 branch range and
    # the macOS linker fails. Upstream switched [profile.release] from
    # lto = "fat" to lto = "thin" in 0.139.0, so match the current value.
    substituteInPlace Cargo.toml \
      --replace-fail 'lto = "thin"' 'lto = false'
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
