{
  lib,
  stdenv,
  fetchFromGitHub,
  installShellFiles,
  rustPlatform,
  pkg-config,
  openssl,
  dbus,
  versionCheckHook,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash cargoHash;
in
rustPlatform.buildRustPackage {
  pname = "codewhale";
  inherit version;

  src = fetchFromGitHub {
    owner = "Hmbown";
    repo = "CodeWhale";
    tag = "v${version}";
    inherit hash;
  };

  inherit cargoHash;

  # Build only the user-facing binaries (`codewhale` dispatcher and the
  # `codewhale-tui` runtime). The workspace's default-members also pull in
  # `codewhale-app-server`, which is linked into the TUI crate, so we
  # don't need to build it as a separate binary.
  cargoBuildFlags = [
    "--package"
    "codewhale-cli"
    "--package"
    "codewhale-tui"
  ];

  nativeBuildInputs = [
    installShellFiles
    pkg-config
  ];

  buildInputs =
    [ openssl ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ dbus ];

  doCheck = false;

  # The final link of this multi-crate workspace can run silently for well
  # over 30 minutes on slower builders (x86_64-darwin via Rosetta on
  # aarch64 hardware), tripping Nix's max-silent-time default of 1800s.
  # Emit a heartbeat every 60s during the build so it stays alive (same
  # approach as pkgs/openclaw).
  preBuild = ''
    ( while true; do echo "[heartbeat] still building codewhale..."; sleep 60; done ) &
    _codewhale_heartbeat_pid=$!
  '';
  postBuild = ''
    kill "$_codewhale_heartbeat_pid" 2>/dev/null || true
  '';

  postInstall = ''
    installShellCompletion --cmd codewhale \
      --bash <($out/bin/codewhale completion bash) \
      --fish <($out/bin/codewhale completion fish) \
      --zsh <($out/bin/codewhale completion zsh)
  '';

  # Skip the emulated `codewhale --version` check on x86_64-darwin: under
  # Rosetta the emulated binary can hang past the 1800s builder timeout
  # (same reason claude-code gates its install check on this platform).
  doInstallCheck = stdenv.hostPlatform.system != "x86_64-darwin";
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Agentic coding terminal for open-source and open-weight models";
    homepage = "https://github.com/Hmbown/CodeWhale";
    changelog = "https://github.com/Hmbown/CodeWhale/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "codewhale";
    platforms = lib.platforms.unix;
  };
}
