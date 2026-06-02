{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  cmake,
  gitMinimal,
  coreutils,
  apple-sdk_15,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    srcHash
    vendorHash
    llamaCppTag
    llamaCppHash
    ;

  # ollama 0.30+ no longer vendors llama.cpp in-tree. Its CMake build
  # fetches a pinned llama.cpp commit (see ollama's LLAMA_CPP_VERSION) via
  # FetchContent at build time, which can't reach the network in the Nix
  # sandbox. Prefetch that exact revision so the build can consume it
  # offline (wired in via preBuild below).
  llamaCppSrc = fetchFromGitHub {
    owner = "ggml-org";
    repo = "llama.cpp";
    tag = llamaCppTag;
    hash = llamaCppHash;
  };
in
buildGoModule (finalAttrs: {
  pname = "ollama";
  inherit version;

  src = fetchFromGitHub {
    owner = "ollama";
    repo = "ollama";
    tag = "v${version}";
    hash = srcHash;
  };

  inherit vendorHash;
  proxyVendor = true;

  nativeBuildInputs = [
    cmake
    gitMinimal
  ];

  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    apple-sdk_15
  ];

  # Mirrors nixpkgs ollama: stamp the version and rewrite a few
  # /bin/<tool> shellouts in launch tests so they resolve in the
  # build sandbox.
  postPatch = ''
    substituteInPlace version/version.go \
      --replace-fail 0.0.0 '${finalAttrs.version}'
    for f in cmd/launch/openclaw_test.go \
             cmd/launch/hermes_test.go \
             cmd/launch/kimi_test.go; do
      [ -f "$f" ] || continue
      substituteInPlace "$f" \
        --replace-quiet '/bin/mkdir' '${coreutils}/bin/mkdir' \
        --replace-quiet '/bin/cat'   '${coreutils}/bin/cat' \
        --replace-quiet '/bin/chmod' '${coreutils}/bin/chmod'
    done
    rm -rf app
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    # Tests that call into Metal can't initialise inside the
    # build sandbox.
    rm -f ml/backend/ggml/ggml_test.go
    rm -f ml/nn/pooling/pooling_test.go
  '';

  overrideModAttrs = (
    _finalAttrs: _prevAttrs: {
      preBuild = "";
    }
  );

  preBuild = ''
    # Hand the prefetched llama.cpp tree to CMake's FetchContent instead of
    # letting it git-clone at build time. Copy to a writable location first:
    # Ollama's compat layer patches the llama.cpp source in place during
    # configure, and the Nix store copy is read-only.
    cp -r ${llamaCppSrc} llama-cpp-src
    chmod -R u+w llama-cpp-src

    # OLLAMA_MLX_BACKENDS="" disables the new Apple MLX backend, whose
    # auto-detection demands Xcode's full Metal toolchain (unavailable in
    # the sandbox). Metal acceleration still comes via llama.cpp/ggml.
    cmake -B build \
      -DFETCHCONTENT_SOURCE_DIR_LLAMA_CPP="$PWD/llama-cpp-src" \
      -DOLLAMA_MLX_BACKENDS="" \
      -DCMAKE_SKIP_BUILD_RPATH=ON \
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    cmake --build build -j $NIX_BUILD_CORES
  '';

  postInstall = ''
    mkdir -p $out/lib
    cp -r build/lib/ollama $out/lib/
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    # The llama.cpp CPU backend variants are built in a CMake
    # ExternalProject and copied into lib/ollama via a raw file(GLOB)
    # install, so they keep their build-tree RPATH — a forbidden
    # reference to /build/. Strip those entries; the libraries sit
    # beside their dependencies ($ORIGIN), and the remaining entries
    # already point into the store.
    for f in $out/lib/ollama/*; do
      [ -f "$f" ] || continue
      rpath=$(patchelf --print-rpath "$f" 2>/dev/null) || continue
      [ -n "$rpath" ] || continue
      cleaned=$(printf '%s' "$rpath" | tr ':' '\n' \
        | grep -v '^/build' | paste -sd: -)
      patchelf --set-rpath "$cleaned" "$f"
    done
  '';

  ldflags = [
    "-X=github.com/ollama/ollama/version.Version=${finalAttrs.version}"
    "-X=github.com/ollama/ollama/server.mode=release"
  ];

  __darwinAllowLocalNetworking = true;

  sandboxProfile =
    lib.optionalString stdenv.hostPlatform.isDarwin ''
      (allow file-read* (subpath "/System/Library/Extensions"))
      (allow iokit-open
        (iokit-user-client-class "AGXDeviceUserClient"))
    '';

  checkFlags =
    let
      skippedTests = [
        # writes to $HOME, see ollama/ollama#12307
        "TestPushHandler/unauthorized_push"
        # needs network access for npm install
        "TestPiRun_InstallAndWebSearchLifecycle"
        # depend on a bundled plugin install path that
        # isn't populated inside the build sandbox
        "TestOpenclawRun_FirstLaunchOnboardUsesLaunchManagedHealthFlow"
        "TestEnsureOpenclawInstalled_UsesBundledPluginInstallEnv"
      ];
    in
    [ "-skip=^${builtins.concatStringsSep "$|^" skippedTests}$" ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = "HOME";

  meta = {
    description =
      "Get up and running with large language models locally";
    homepage = "https://github.com/ollama/ollama";
    changelog =
      "https://github.com/ollama/ollama/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "ollama";
    platforms = lib.platforms.unix;
  };
})
