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

  postInstall = ''
    installShellCompletion --cmd codewhale \
      --bash <($out/bin/codewhale completion bash) \
      --fish <($out/bin/codewhale completion fish) \
      --zsh <($out/bin/codewhale completion zsh)
  '';

  doInstallCheck = true;
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
