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

  # agent-deck 1.9.49 added a test-only data-loss guard (internal/agentpaths)
  # that, while testing.Testing() is true, refuses to resolve any agent-deck
  # path under the OS user's *real* home -- read from the passwd database via
  # user.Current(), independent of $HOME. In the hermetic Nix build sandbox the
  # build user's passwd home is /build, and every temp dir (TMPDIR, t.TempDir,
  # testutil.IsolateHome's mktemp) also lives under /build. So the guard treats
  # every sandboxed test path as "the real home" and fails closed, breaking all
  # ~40 cmd/agent-deck tests (path resolution, version nudge, XDG, mutations).
  # Neutralise the guard for the build by making osUserRealHome() report no real
  # home: there is no real user data to protect in the sandbox, and the guard is
  # test-only so production path resolution is unaffected.
  postPatch = ''
    substituteInPlace internal/agentpaths/paths.go \
      --replace-fail 'return filepath.Clean(u.HomeDir)' 'return ""'
  '';

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
