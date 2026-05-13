{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash vendorHash;
in
buildGoModule (finalAttrs: {
  pname = "agent-deck";
  inherit version;

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    tag = "v${finalAttrs.version}";
    hash = srcHash;
  };

  inherit vendorHash;

  subPackages = [ "cmd/agent-deck" ];

  # The OBS-01 wiring test compiles the binary, launches the full TUI
  # in a subprocess and waits for it to write debug.log. The TUI bails
  # in the sandbox (no tmux/terminal), so debug.log never appears. The
  # test guards the subprocess arm with testing.Short(), so honour that.
  #
  # TestValidatePluginFlags_* relies on a process-wide config cache keyed
  # on file mtime. On fast Linux filesystems (tmpfs in the Nix sandbox)
  # mtimes collide between tests, so the catalog from an earlier test
  # leaks into a later one and the assertion flips. Upstream's
  # clearSessionUserConfigCache is a no-op (see plugin_cli_test.go:35).
  # Darwin's coarser mtime resolution hides this. Skip the group until
  # upstream wires real cache invalidation.
  checkFlags = [
    "-short"
    "-skip"
    "^TestValidatePluginFlags_"
  ];

  preCheck = ''
    export HOME=$(mktemp -d)
    export PATH="${git}/bin:$PATH"
  '';

  ldflags = [
    "-s"
    "-w"
    "-X=main.Version=${finalAttrs.version}"
  ];

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    writableTmpDirAsHomeHook
    versionCheckHook
  ];

  meta = {
    description = "Your AI agent command center";
    homepage = "https://github.com/asheshgoplani/agent-deck";
    changelog = "https://github.com/asheshgoplani/agent-deck/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    mainProgram = "agent-deck";
  };
})
