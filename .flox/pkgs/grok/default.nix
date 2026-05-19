{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  versionCheckHook,
  writableTmpDirAsHomeHook,
  bashInteractive,
  bubblewrap,
  zsh,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hashes;

  platformMap = {
    x86_64-linux = "linux-x86_64";
    aarch64-linux = "linux-aarch64";
    aarch64-darwin = "macos-aarch64";
  };

  platform = stdenv.hostPlatform.system;
  platformSuffix = platformMap.${platform} or (throw "Unsupported system: ${platform}");

  # Grok's run_command tool spawns shells via portable_pty which execve's
  # absolute paths like /bin/bash and /bin/zsh (derived from $SHELL, with
  # /bin/bash as the hardcoded fallback). NixOS only ships /bin/sh, so
  # every shell tool call fails before any user command runs.
  #
  # As a transitional workaround, wrap the Linux entry points with
  # bubblewrap so /bin is replaced by a tmpfs containing symlinks to the
  # matching shells from the Nix store. Remove once upstream grok honors
  # $SHELL (or PATH) instead of fixed /bin/* paths.
  bwrapFlags = lib.concatStringsSep " " [
    "--dev-bind / /"
    "--tmpfs /bin"
    "--symlink ${bashInteractive}/bin/bash /bin/bash"
    "--symlink ${zsh}/bin/zsh /bin/zsh"
    "--symlink ${bashInteractive}/bin/sh /bin/sh"
  ];
in
stdenv.mkDerivation {
  pname = "grok";
  inherit version;

  src = fetchurl {
    url =
      "https://storage.googleapis.com/grok-build-public-artifacts"
      + "/cli/grok-${version}-${platformSuffix}";
    hash = hashes.${platform};
  };

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/libexec/grok/grok

    makeWrapper $out/libexec/grok/grok $out/libexec/grok/grok-launcher \
      --argv0 grok \
      --add-flags --no-auto-update

    makeWrapper $out/libexec/grok/grok $out/libexec/grok/agent-launcher \
      --argv0 agent \
      --add-flags --no-auto-update
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    install -d $out/bin
    for name in grok agent; do
      {
        printf '#!%s\n' '${stdenv.shell}'
        printf 'exec %s %s -- %s/libexec/grok/%s-launcher "$@"\n' \
          '${bubblewrap}/bin/bwrap' \
          '${bwrapFlags}' \
          "$out" \
          "$name"
      } > $out/bin/$name
      chmod +x $out/bin/$name
    done
  ''
  + lib.optionalString (!stdenv.hostPlatform.isLinux) ''
    install -d $out/bin
    ln -s $out/libexec/grok/grok-launcher $out/bin/grok
    ln -s $out/libexec/grok/agent-launcher $out/bin/agent
  ''
  + ''

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "Grok Build, xAI's agentic coding tool";
    homepage = "https://x.ai";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [
      binaryNativeCode
    ];
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    mainProgram = "grok";
  };
}
