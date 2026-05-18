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
  pname = "deepseek-tui";
  inherit version;

  src = fetchFromGitHub {
    owner = "Hmbown";
    repo = "DeepSeek-TUI";
    tag = "v${version}";
    inherit hash;
  };

  inherit cargoHash;

  # Build only the user-facing binaries (`deepseek` dispatcher and the
  # `deepseek-tui` runtime). The workspace's default-members also pull in
  # `deepseek-app-server`, which is linked into the TUI crate, so we
  # don't need to build it as a separate binary.
  cargoBuildFlags = [
    "--package"
    "deepseek-tui-cli"
    "--package"
    "deepseek-tui"
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
    installShellCompletion --cmd deepseek \
      --bash <($out/bin/deepseek completion bash) \
      --fish <($out/bin/deepseek completion fish) \
      --zsh <($out/bin/deepseek completion zsh)
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Coding agent for DeepSeek models that runs in your terminal";
    homepage = "https://github.com/Hmbown/DeepSeek-TUI";
    changelog = "https://github.com/Hmbown/DeepSeek-TUI/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "deepseek";
    platforms = lib.platforms.unix;
  };
}
