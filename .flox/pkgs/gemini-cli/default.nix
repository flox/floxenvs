{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  ripgrep,
  pkg-config,
  libsecret,
  clang_20,
  makeBinaryWrapper,
  makeSetupHook,
  writeText,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  writeShellScriptBin,
  xsel,
  nodejs,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash npmDepsHash;

  # node-gyp on macOS sometimes picks up node.js's util.h before the SDK's,
  # so openpty()/forkpty() prototypes go missing and node-pty fails to
  # build. Inject a shim header via -include so the prototypes are always
  # in scope. Mirrors numtide/llm-agents.nix's darwinOpenptyHook.
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
buildNpmPackage (finalAttrs: {
  npmDepsFetcherVersion = 2;
  pname = "gemini-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "google-gemini";
    repo = "gemini-cli";
    tag = "v${version}";
    hash = srcHash;
  };

  inherit npmDepsHash;
  makeCacheWritable = true;

  nativeBuildInputs = [
    pkg-config
    makeBinaryWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    # node-addon-api needs clang 20; clang 21+ fails on a constexpr issue.
    clang_20
    # Fixes node-pty openpty/forkpty build issue.
    darwinOpenptyHook
  ];

  dontPatchElf = stdenv.hostPlatform.isDarwin;

  buildInputs = [
    libsecret
  ];

  preConfigure = ''
    mkdir -p packages/generated
    echo "export const GIT_COMMIT_INFO = { commitHash: '${finalAttrs.src.rev}' };" \
      > packages/generated/git-commit.ts
  '';

  postPatch = ''
    # Hardcode ripgrep path so ensureRgPath() returns our Nix-provided binary
    # instead of downloading or finding a dynamically-linked one.
    substituteInPlace packages/core/src/tools/ripGrep.ts \
      --replace-fail "await ensureRgPath();" "'${lib.getExe ripgrep}';"

    # Disable auto-update and the update nag - Nix manages updates.
    sed -i "/enableAutoUpdate: {/,/}/ s/default: true/default: false/" \
      packages/cli/src/config/settingsSchema.ts
    sed -i "/enableAutoUpdateNotification: {/,/}/ s/default: true/default: false/" \
      packages/cli/src/config/settingsSchema.ts
  '';

  # v0.31.0 added @google/gemini-cli-devtools as an implicit workspace
  # dependency of cli. npm --workspaces builds packages alphabetically
  # (cli before devtools), so tsc fails to resolve the import. Pre-build
  # devtools so its types are available when cli compiles.
  preBuild = ''
    npm run build --workspace=@google/gemini-cli-devtools
  '';

  # Prevent build-only deps from leaking into the runtime closure
  disallowedReferences = [
    finalAttrs.npmDeps
    nodejs.python
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/{bin,share/gemini-cli}

    npm prune --omit=dev

    cp -r node_modules $out/share/gemini-cli/

    # Replace workspace symlinks with the actual built packages
    for pkg in cli:gemini-cli core:gemini-cli-core \
               a2a-server:gemini-cli-a2a-server \
               devtools:gemini-cli-devtools sdk:gemini-cli-sdk; do
      dir=''${pkg%%:*}
      name=''${pkg##*:}
      rm -f $out/share/gemini-cli/node_modules/@google/"$name"
      cp -r packages/"$dir" \
        $out/share/gemini-cli/node_modules/@google/"$name"
    done
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-test-utils
    rm -f $out/share/gemini-cli/node_modules/gemini-cli-vscode-ide-companion

    # Remove dangling symlinks to source directory
    rm -f $out/share/gemini-cli/node_modules/@google/gemini-cli-core/dist/docs/CONTRIBUTING.md

    makeWrapper ${lib.getExe nodejs} $out/bin/gemini \
      --add-flags "--no-warnings=DEP0040" \
      --add-flags "$out/share/gemini-cli/node_modules/@google/gemini-cli/dist/index.js" \
      ${lib.optionalString stdenv.hostPlatform.isLinux "--prefix PATH : ${lib.makeBinPath [ xsel ]}"}

    # Install JSON schema
    install -Dm644 schemas/settings.schema.json \
      $out/share/gemini-cli/settings.schema.json

    runHook postInstall
  '';

  # Remove files that embed build-time store paths (python shebangs, build
  # artifacts, lockfiles) to satisfy disallowedReferences. Must run in
  # preFixup before patchShebangs rewrites shebangs to Nix store paths.
  preFixup = ''
    find $out/share/gemini-cli/node_modules \
      -name "*.py" -o -name "gyp-mac-tool" \
      -o -name "package-lock.json" -o -name ".package-lock.json" \
      -o -name "config.gypi" \
      -o -path '*/build/*.mk' -o -path '*/build/Makefile' \
      | xargs rm -f
    # @github/keytar/build: keep only the runtime addon. Object files and
    # .deps/*.d embed paths to nodejs-source and -dev outputs, bloating
    # the closure.
    find $out/share/gemini-cli/node_modules/@github/keytar/build \
      -type f -not -name 'keytar.node' -delete
    find $out/share/gemini-cli/node_modules/@github/keytar/build \
      -type d -empty -delete
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    # clipboardy → system-architecture calls
    # `sysctl -inq sysctl.proc_translated` at import time to detect
    # Rosetta 2. In the Nix sandbox /usr/sbin/sysctl is absent, causing
    # ENOENT and crashing the version check. Stub it to report "not
    # translated" so the module resolves the native arch.
    (writeShellScriptBin "sysctl" "echo 0")
  ];
  # versionCheckHook runs with --ignore-environment by default, stripping
  # PATH. Preserve it so the sysctl stub (and node itself) can be found
  # by child processes spawned during `gemini --version`.
  versionCheckKeepEnvironment = "PATH";

  meta = {
    description = "AI agent that brings Gemini directly into your terminal";
    homepage = "https://github.com/google-gemini/gemini-cli";
    changelog = "https://github.com/google-gemini/gemini-cli/releases/tag/v${version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    mainProgram = "gemini";
  };
})
