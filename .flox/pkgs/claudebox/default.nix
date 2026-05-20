{
  lib,
  stdenv,
  callPackage,
  fetchFromGitHub,
  buildEnv,
  runCommand,
  makeWrapper,
  bun,
  bashInteractive,
  # Tools bundled into the sandboxed environment
  git,
  ripgrep,
  fd,
  coreutils,
  gnugrep,
  gnused,
  gawk,
  findutils,
  which,
  tree,
  curl,
  wget,
  jq,
  less,
  zsh,
  nix,
  # Platform-specific sandbox primitive
  bubblewrap,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash;

  # Build claude-code from this repo so claudebox bundles the same
  # version flox publishes; the wrapper calls it via $out/libexec.
  claude-code = callPackage ../claude-code { };

  src = fetchFromGitHub {
    owner = "numtide";
    repo = "claudebox";
    tag = "v${version}";
    hash = srcHash;
  };

  # Bundle the tools claude commonly invokes into one PATH entry.
  claudeTools = buildEnv {
    name = "claude-tools";
    paths = [
      git
      ripgrep
      fd
      coreutils
      gnugrep
      gnused
      gawk
      findutils
      which
      tree
      curl
      wget
      jq
      less
      zsh
      nix
    ];
  };

  sandboxTools = lib.optionals stdenv.hostPlatform.isLinux [ bubblewrap ];
in
runCommand "claudebox-${version}"
  {
    nativeBuildInputs = [ makeWrapper ];
    meta = {
      description = "Sandboxed environment for running Claude Code";
      homepage = "https://github.com/numtide/claudebox";
      changelog = "https://github.com/numtide/claudebox/releases/tag/v${version}";
      license = lib.licenses.mit;
      sourceProvenance = with lib.sourceTypes; [ fromSource ];
      platforms = lib.platforms.linux ++ lib.platforms.darwin;
      mainProgram = "claudebox";
    };
  }
  ''
    mkdir -p $out/bin $out/share/claudebox $out/libexec/claudebox

    cp ${src}/src/claudebox.js $out/libexec/claudebox/claudebox.js
    cp ${./seatbelt.sbpl} $out/share/claudebox/seatbelt.sbpl

    makeWrapper ${bun}/bin/bun $out/bin/claudebox \
      --add-flags $out/libexec/claudebox/claudebox.js \
      --prefix PATH : ${
        lib.makeBinPath (
          [
            bashInteractive
            claudeTools
          ]
          ++ sandboxTools
        )
      } \
      ${lib.optionalString stdenv.hostPlatform.isDarwin "--set CLAUDEBOX_SEATBELT_PROFILE $out/share/claudebox/seatbelt.sbpl"}

    # The wrapper invokes the real claude binary indirectly via libexec
    # so the autoupdater can be disabled and argv0 preserved.
    makeWrapper ${claude-code}/bin/.claude-wrapped \
      $out/libexec/claudebox/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --inherit-argv0
  ''
