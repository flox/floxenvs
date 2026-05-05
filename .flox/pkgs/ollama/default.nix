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
  inherit (versionData) version srcHash vendorHash;
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
    cmake -B build \
      -DCMAKE_SKIP_BUILD_RPATH=ON \
      -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON
    cmake --build build -j $NIX_BUILD_CORES
  '';

  postInstall = ''
    mkdir -p $out/lib
    cp -r build/lib/ollama $out/lib/
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
