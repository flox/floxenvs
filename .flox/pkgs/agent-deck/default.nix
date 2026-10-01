{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  git,
  lsof,
  procps,
  tmux,
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

    # Upstream commits its own `.flox/env/manifest.lock`, which is full
    # of `/nix/store/...` paths. A fetched source is a fixed-output
    # derivation, and modern Nix refuses FODs that reference store paths
    # ("fixed-output derivations must not reference store paths"). The
    # lockfile is irrelevant to building the Go binary, so drop it before
    # the output is hashed. (Recompute `srcHash` in upgrade.sh after
    # changing this.)
    postFetch = ''
      rm -rf "$out/.flox"
    '';
  };

  inherit vendorHash;

  subPackages = [ "cmd/agent-deck" ];

  # Downstream patch: add an AGENT_DECK_HOME env var that overrides XDG_*
  # path resolution, so flox-ai can isolate a per-project agent-deck home
  # without hijacking XDG_CONFIG_HOME/XDG_DATA_HOME (which would otherwise
  # leak into agent-deck's tmux panes and break unrelated programs). The
  # override is added in internal/agentpaths, the single funnel every config,
  # data, and cache path resolves through. Applied in patchPhase, before the
  # postPatch surgery below; affects neither srcHash (fixed-output fetch) nor
  # vendorHash (Go module graph unchanged). Upstream PR pending; drop this
  # once merged.
  patches = [ ./agent-deck-home.patch ];

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
  #
  # TestIssue2388_CapabilitiesCarryProbe's fake `codex debug models`
  # shim hardcodes PATH to `<fixture dir>:/usr/bin:/bin`, but neither
  # /usr/bin nor /bin exists in the Nix sandbox, so its `cat` call
  # fails closed and the probe falls back to the static list (fails in
  # 0.00s -- confirmed not a timeout). Append the sandbox's real PATH
  # so the shim's `cat` resolves.
  postPatch = ''
    substituteInPlace internal/agentpaths/paths.go \
      --replace-fail 'return filepath.Clean(u.HomeDir)' 'return ""'

    substituteInPlace cmd/agent-deck/issue2388_capabilities_models_test.go \
      --replace-fail \
        't.Setenv("PATH", dir+string(os.PathListSeparator)+"/usr/bin"+string(os.PathListSeparator)+"/bin")' \
        't.Setenv("PATH", dir+string(os.PathListSeparator)+"/usr/bin"+string(os.PathListSeparator)+"/bin"+string(os.PathListSeparator)+os.Getenv("PATH"))'
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
  # On darwin the three live-process cleanup-safety tests spawn a
  # subprocess and poll its cwd via lsof; the darwin Nix sandbox denies
  # lsof access to other processes' file tables, so the helper exits 1.
  # Skip them there only — on Linux they run (procfs works in the
  # sandbox), and the remaining cleanup-safety tests (unpushed/dirty
  # exclusion) run everywhere with lsof on PATH.
  #
  # 1.16.11's remote-parity suite drives a real OpenSSH client against an
  # in-process SSH server fixture. Its sibling tests call t.Skip when
  # exec.LookPath("ssh") fails, so they stay dormant in the sandbox, but
  # the new TestHealthRemoteExecJSONParity calls t.Fatal instead
  # ("health parity requires OpenSSH client") and fails the build. Skip
  # it rather than putting openssh on PATH: that wakes the whole suite,
  # whose fixtures need `python3 -u receiver.py` under a live tmux PTY
  # and a 10s readiness deadline — unreachable on darwin and flaky on
  # loaded Linux builders.
  #
  # TestRecallSearch_FederatedMergesAndLabels (new in 1.16.16) answers a
  # forwarded `recall search` from a `#!/bin/sh` shim whose printf format
  # string embeds escaped quotes ("match": "\"retry\" \"budget\"").
  # bash 3.2 — darwin's /bin/sh — drops those backslashes, so the shim
  # emits ""retry" "budget"" and the caller rejects it with
  # `invalid character 'r' after object key:value pair`. Newer shells keep
  # the backslash, so Linux passes. Upstream test bug, darwin only.
  #
  # TestSessionContextJSONGolden/claude-model-switch redacts the fixture
  # root out of the golden document by slugifying it into a Claude Code
  # project key. The darwin builder's sandbox path
  # (/private/tmp/nix-build-agent-deck-<ver>.drv-0/...) slugifies past
  # the length the redaction expects, so the raw path leaks into the
  # produced document and the comparison fails. Linux's shorter /build
  # path redacts cleanly, so skip that one on darwin only.
  #
  # The darwin Nix sandbox denies `ps` the same way it denies lsof
  # above -- confirmed by CI: "fork/exec /bin/ps: operation not
  # permitted", not a PATH gap, so no PATH addition can fix it. That
  # breaks every session-restart/ownership identity check
  # (internal/procowner's darwin prober calls `ps` after its `sysctl`
  # boot-id check) and the writer-lock suite's process-tree walk
  # (`ps -eo pid=,ppid=` is collectTmuxPaneProcessTreePIDs's primary
  # lookup too). Skip both groups on darwin only; Linux has ps/pgrep
  # via procps below and both groups pass there.
  checkFlags = [
    "-short"
    "-skip"
    (
      "^TestValidatePluginFlags_"
      + "|^TestHealthRemoteExecJSONParity$"
      + lib.optionalString stdenv.hostPlatform.isDarwin (
        "|^TestRecallSearch_FederatedMergesAndLabels$"
        + "|^TestSessionContextJSONGolden$"
        + "|^TestCleanupExcludesLiveProcessCWDInside$"
        + "|^TestCleanupRevalidatesRealityBeforeRemoval$"
        + "|^TestCleanupForceCannotOverrideRealityExclusions$"
        + "|^TestCoreRegistryMatchesLegacyHandlers$"
        + "|^TestDaemonEnvelopesMatchArgv$"
        + "|^TestDaemonRestartAllReturnsCompletedResult$"
        + "|^TestStorageBytesGoldens$"
        + "|^TestCodexAcceptanceGuardAcceptsFreshComposerThread$"
        + "|^TestIssue2394_HydratePrefersLiveThreadOverGuessedPaneIdentity$"
        + "|^TestIssue2396_FirstTurnOutputIsBoundToItsConversation$"
        + "|^TestIssue2400_ArchiveKeepsLiveCodexIdentity$"
      )
    )
  ];

  # lsof: the 1.15.0 worktree-cleanup safety tests shell out to lsof to
  # inspect live processes; without it every cleanup candidate is treated
  # as protected and the tests fail (surfaced on darwin builders).
  #
  # tmux: 1.16.x moved the "tmux not found" preflight ahead of command
  # dispatch, so every cmd/agent-deck test that runs a command (account
  # registration, visibility, worktree boundary, ...) aborts with
  # "Error: tmux not found" unless tmux is on PATH.
  #
  # procps (linux only): the writer-lock live-identity suite (#2394/
  # #2396/#2400, fresh-composer guard -- new in 1.16.22) walks the
  # pane's process tree with `ps`/`pgrep` to find the fd holding the
  # writer lock. Neither is on the sandbox's base PATH, so the walk
  # always comes back empty and the tests spin out their 10s poll
  # (confirmed via a diagnostic run: ps/pgrep exit 127; the fd itself
  # already resolves fine via /proc). procps supplies both on Linux;
  # darwin has no equivalent PATH fix -- ps is sandbox-denied there
  # regardless of PATH, see the checkFlags comment above.
  #
  # /usr/sbin (darwin only): the darwin prober's `sysctl -n
  # kern.boottime` boot-id check is a plain PATH gap, unlike `ps` --
  # /usr/sbin isn't on the sandbox's base PATH, but sysctl execs
  # fine once it's found.
  preCheck = ''
    export HOME=$(mktemp -d)
    export PATH="${git}/bin:${lsof}/bin:${tmux}/bin:$PATH"
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    export PATH="${procps}/bin:$PATH"
  ''
  + lib.optionalString stdenv.hostPlatform.isDarwin ''
    export PATH="/usr/sbin:$PATH"
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
