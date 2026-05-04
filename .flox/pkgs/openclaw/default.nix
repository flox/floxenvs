{
  lib,
  stdenv,
  buildPackages,
  fetchFromGitHub,
  fetchPnpmDeps,
  cmake,
  git,
  pnpmConfigHook,
  pnpm_10,
  nodejs_22,
  makeWrapper,
  versionCheckHook,
  installShellFiles,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash pnpmDepsHash;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "openclaw";
  inherit version;

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "openclaw";
    tag = "v${version}";
    inherit hash;
  };

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    pnpm = pnpm_10;
    fetcherVersion = 3;
    hash = pnpmDepsHash;
  };

  nativeBuildInputs = [
    cmake
    git
    pnpmConfigHook
    pnpm_10
    nodejs_22
    makeWrapper
    installShellFiles
  ];

  # cmake is only needed for a few npm postinstall scripts; stop it from
  # running as the configure phase of this derivation.
  dontUseCmakeConfigure = true;

  preBuild = ''
    # rolldown is a transitive dependency (via tsdown), not a direct root
    # dependency, so pnpm does not link its binary into node_modules/.bin.
    # scripts/bundle-a2ui.mjs probes two hard-coded paths for cli.mjs and
    # falls back to `pnpm dlx rolldown` (network) when neither is present.
    # Upstream sets `node-linker=hoisted` in .npmrc so rolldown lands at
    # node_modules/rolldown; symlink it into the pnpm-isolated path the
    # probe expects so the pre-fetched binary is used.
    if [ ! -e node_modules/rolldown/bin/cli.mjs ]; then
      echo "error: rolldown cli.mjs not found in node_modules" >&2
      exit 1
    fi
    mkdir -p node_modules/.pnpm/node_modules
    ln -sfT ../../rolldown node_modules/.pnpm/node_modules/rolldown
  '';

  buildPhase = ''
    runHook preBuild

    pnpm build
    pnpm ui:build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    libdir=$out/lib/openclaw
    mkdir -p $libdir $out/bin

    # Copy the full tree (including monorepo packages/, ui/, and extensions/)
    # then prune dev/test files not needed at runtime.
    cp --reflink=auto -r . $libdir/

    pushd $libdir
    rm -rf \
      src \
      test \
      apps \
      Swabble \
      Peekaboo \
      git-hooks \
      tsconfig.json tsconfig.*.json \
      vitest.config.ts vitest.*.config.ts \
      tsdown.config.ts \
      Dockerfile Dockerfile.* \
      docker-compose.yml docker-setup.sh \
      README-header.png \
      CHANGELOG.md CONTRIBUTING.md SECURITY.md VISION.md INCIDENT_RESPONSE.md \
      appcast.xml \
      pnpm-lock.yaml pnpm-workspace.yaml \
      assets/dmg-background.png \
      assets/dmg-background-small.png
    find . -name "__screenshots__" -type d -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.test.ts" -delete
    find . -name "*.test.js" -delete
    popd

    rm -f $libdir/node_modules/.pnpm/node_modules/clawdbot \
      $libdir/node_modules/.pnpm/node_modules/moltbot \
      $libdir/node_modules/.pnpm/node_modules/openclaw-control-ui

    makeWrapper ${lib.getExe nodejs_22} $out/bin/openclaw \
      --add-flags "$libdir/openclaw.mjs" \
      --set NODE_PATH "$libdir/node_modules"
    ln -s $out/bin/openclaw $out/bin/moltbot
    ln -s $out/bin/openclaw $out/bin/clawdbot

    runHook postInstall
  '';

  postInstall = lib.optionalString (stdenv.hostPlatform.emulatorAvailable buildPackages) (
    let
      emulator = stdenv.hostPlatform.emulator buildPackages;
    in
    ''
      installShellCompletion --cmd openclaw \
        --bash <(${emulator} $out/bin/openclaw completion --shell bash) \
        --fish <(${emulator} $out/bin/openclaw completion --shell fish) \
        --zsh <(${emulator} $out/bin/openclaw completion --shell zsh)
    ''
  );

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  # Upstream tags may carry a "-N" rebuild suffix (e.g. v2026.4.21-1) while
  # `openclaw --version` only reports the base version. Strip the suffix
  # before versionCheckHook compares it against the command output.
  preVersionCheck = ''
    version=${lib.head (lib.splitString "-" finalAttrs.version)}
  '';

  meta = {
    description = "Self-hosted, open-source AI assistant/agent";
    homepage = "https://openclaw.ai";
    changelog = "https://github.com/openclaw/openclaw/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = with lib.platforms; linux ++ darwin;
    mainProgram = "openclaw";
  };
})
