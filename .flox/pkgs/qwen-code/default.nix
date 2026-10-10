{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_11,
  nodejs,
  git,
  ripgrep,
  pkg-config,
  glib,
  libsecret,
  clang_20,
  makeSetupHook,
  writeText,
  writeShellScriptBin,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash pnpmDepsHash;
  pnpm = pnpm_11;

  # scripts/build.js shells out to `corepack pnpm -r ... run build`, and
  # corepack honours package.json's `packageManager` by downloading that
  # exact pnpm. The build sandbox has no network, so it dies with
  #   Error: unable to get local issuer certificate
  #   code: 'UNABLE_TO_GET_ISSUER_CERT_LOCALLY'
  # pnpm is already in nativeBuildInputs at a version that reads this
  # lockfile, so shadow corepack with a shim that drops the
  # package-manager argument and runs the one from the closure.
  corepackShim = writeShellScriptBin "corepack" ''
    pm="$1"
    shift
    exec "$pm" "$@"
  '';

  # node-gyp on macOS sometimes picks up node.js's util.h before the SDK's,
  # so openpty()/forkpty() prototypes go missing and node-pty fails to
  # build. Inject a shim header via -include so the prototypes are always
  # in scope.
  darwinOpenptyHook =
    let
      shim = writeText "darwin-openpty-shim.h" ''
        #ifndef DARWIN_OPENPTY_SHIM_H
        #define DARWIN_OPENPTY_SHIM_H
        #include <sys/types.h>
        struct termios;
        struct winsize;
        #ifdef __cplusplus
        extern "C" {
        #endif
        int openpty(int *, int *, char *, struct termios *, struct winsize *);
        pid_t forkpty(int *, char *, struct termios *, struct winsize *);
        #ifdef __cplusplus
        }
        #endif
        #endif
      '';
      hookScript = writeText "darwin-openpty-hook.sh" ''
        if [ -z "''${darwinOpenptyHookApplied-}" ]; then
          export NIX_CFLAGS_COMPILE="''${NIX_CFLAGS_COMPILE-} -include ${shim}"
          darwinOpenptyHookApplied=1
        fi
      '';
    in
    makeSetupHook { name = "darwin-openpty-hook"; } hookScript;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "qwen-code";
  inherit version;

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    tag = "v${version}";
    hash = srcHash;
  };

  # 0.25.0 migrated the repo from npm to pnpm: package-lock.json is gone,
  # replaced by pnpm-lock.yaml plus pnpm-workspace.yaml, and package.json
  # declares `packageManager: pnpm@11.x`. buildNpmPackage's fetchNpmDeps
  # has no lockfile to read and fails the build outright with
  # `ERROR: No lock file!`, so fetch the store with pnpm instead.
  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    hash = pnpmDepsHash;
    fetcherVersion = 4;
  };

  nativeBuildInputs = [
    corepackShim
    pkg-config
    git
    nodejs
    pnpm
    pnpmConfigHook
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    # node-addon-api (keytar) needs clang 20; clang 21+ trips on a
    # constexpr issue.
    clang_20
    darwinOpenptyHook
  ];

  buildInputs = [
    ripgrep
    glib
    libsecret
  ];

  buildPhase = ''
    runHook preBuild

    # A dependency whose version conflicts with the hoisted one gets a
    # workspace-local node_modules, and pnpmConfigHook only patches the
    # root tree. Those nested copies keep their `#!/usr/bin/env node`
    # shebangs, and the Linux build sandbox has no /usr/bin/env, so
    # running one dies with "bad interpreter" (exit code 126) — web-shell carries its own vite and hit exactly that. Darwin
    # builders do have /usr/bin/env, so this only bites on Linux.
    #
    # Patch the nested trees, not their .bin directories: the entries in
    # .bin are symlinks, which patchShebangs skips.
    while IFS= read -r nm; do
      patchShebangs "$nm"
    done < <(find packages -type d -name node_modules -prune)

    # Upstream patches ink in place from its root `postinstall`
    # (`patch-package` against patches/ink+7.0.3.patch), and
    # packages/cli compiles against what that patch adds — the
    # `ReadonlyFrame` export and Text's `selectable` prop. pnpmConfigHook
    # installs with lifecycle scripts disabled, so run it here; without
    # it tsc stops with `Module '"ink"' has no exported member
    # 'ReadonlyFrame'` and `Property 'selectable' does not exist`.
    node_modules/.bin/patch-package

    # Upstream's scripts/build.js builds every workspace in dependency
    # order and takes `--cli-only` to skip the ones the CLI bundle does
    # not need (vscode, chrome-extension, qwen-live, the external-context
    # integrations). Call it instead of maintaining our own copy of the
    # order: 0.23.4 inserted packages/web-shell before web-templates, and
    # a hand-kept subset silently fell behind — web-templates failed with
    # `Could not resolve "@qwen-code/web-shell/transcript"`.
    #
    # build.js runs `npm run generate` itself. NODE_OPTIONS mirrors the
    # root `build` script, whose tsc runs need the larger heap.
    NODE_OPTIONS="--max-old-space-size=4096" \
      node scripts/build.js --cli-only
    pnpm run bundle

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/qwen-code
    cp -r dist/* $out/share/qwen-code/
    # Upstream's bin entry is scripts/cli-entry.js (a shebang'd launcher that
    # spawns the bundled dist/cli.js). The esbuild bundle no longer emits a
    # runnable cli.js (no shebang, not executable), so install the wrapper
    # next to cli.js and point qwen at it. package.json is required for the
    # wrapper's --version fast path.
    cp scripts/cli-entry.js $out/share/qwen-code/cli-entry.js
    cp package.json $out/share/qwen-code/package.json
    # pnpm wants to purge and relink node_modules when pruning a
    # workspace, and refuses to do that unprompted:
    #   [ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY] Aborted removal of
    #   modules directory due to no TTY
    # It names the fix itself — settle the prompt in the config rather
    # than exporting CI=true, which other tooling here also reads.
    # --config.ignoreScripts: pruning relinks the store, and pnpm reruns
    # every workspace's lifecycle scripts afterwards. The root one is
    # `patch-package`, a devDependency this prune has just removed, so it
    # dies with `patch-package: command not found` — after the patch has
    # already been applied and built against.
    pnpm prune --prod \
      --config.confirmModulesPurge=false \
      --config.ignoreScripts=true
    cp -r node_modules $out/share/qwen-code/
    # Remove broken symlinks that confuse Nix tooling.
    find $out/share/qwen-code/node_modules -type l -delete || true
    patchShebangs $out/share/qwen-code
    ln -s $out/share/qwen-code/cli-entry.js $out/bin/qwen

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "Command-line AI workflow tool for Qwen3-Coder models";
    homepage = "https://github.com/QwenLM/qwen-code";
    changelog = "https://github.com/QwenLM/qwen-code/releases";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    mainProgram = "qwen";
  };
})
