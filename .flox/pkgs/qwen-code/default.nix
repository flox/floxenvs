{
  lib,
  stdenv,
  buildNpmPackage,
  fetchFromGitHub,
  git,
  ripgrep,
  pkg-config,
  glib,
  libsecret,
  clang_20,
  makeSetupHook,
  writeText,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash npmDepsHash;

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
buildNpmPackage (finalAttrs: {
  npmDepsFetcherVersion = 2;
  pname = "qwen-code";
  inherit version;

  src = fetchFromGitHub {
    owner = "QwenLM";
    repo = "qwen-code";
    tag = "v${version}";
    hash = srcHash;
  };

  inherit npmDepsHash;
  makeCacheWritable = true;

  nativeBuildInputs = [
    pkg-config
    git
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

    npm run generate
    # The CLI esbuild bundle resolves imports against workspace dist/
    # output, so build the workspaces it depends on first (subset of
    # upstream's scripts/build.js buildOrder; the bundled CLI does not
    # pull in webui/sdk/vscode/plugin-example).
    for ws in \
      packages/web-templates \
      packages/channels/base \
      packages/channels/telegram \
      packages/channels/weixin \
      packages/channels/dingtalk
    do
      npm run build --workspace=$ws
    done
    npm run bundle

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/qwen-code
    cp -r dist/* $out/share/qwen-code/
    npm prune --production
    cp -r node_modules $out/share/qwen-code/
    # Remove broken symlinks that confuse Nix tooling.
    find $out/share/qwen-code/node_modules -type l -delete || true
    patchShebangs $out/share/qwen-code
    ln -s $out/share/qwen-code/cli.js $out/bin/qwen

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
      "x86_64-darwin"
      "x86_64-linux"
    ];
    mainProgram = "qwen";
  };
})
