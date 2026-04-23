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
  checkFlags = [ "-short" ];

  preCheck = ''
    export HOME=$(mktemp -d)
    export PATH="${git}/bin:$PATH"
  '';

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${finalAttrs.version}"
    "-X=main.commit=v${finalAttrs.version}"
    "-X=main.date=1970-01-01T00:00:00Z"
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
