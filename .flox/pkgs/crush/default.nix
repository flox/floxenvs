{
  lib,
  stdenv,
  buildGo126Module,
  fetchFromGitHub,
  installShellFiles,
  writableTmpDirAsHomeHook,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash vendorHash;
in
buildGo126Module rec {
  pname = "crush";
  inherit version;

  src = fetchFromGitHub {
    owner = "charmbracelet";
    repo = "crush";
    tag = "v${version}";
    hash = srcHash;
  };

  inherit vendorHash;

  ldflags = [
    "-s"
    "-X=github.com/charmbracelet/crush/internal/version.Version=${version}"
  ];

  nativeBuildInputs = [
    installShellFiles
  ];

  checkFlags =
    let
      skippedTests = [
        "TestCoderAgent"
        "TestOpenAIClientStreamChoices"
        "TestGrepWithIgnoreFiles"
        "TestSearchImplementations"
      ];
    in
    [ "-skip=^${builtins.concatStringsSep "$|^" skippedTests}$" ];

  __darwinAllowLocalNetworking = true;

  nativeCheckInputs = [ writableTmpDirAsHomeHook ];

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  postInstall = lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
    installShellCompletion --cmd crush \
      --bash <($out/bin/crush completion bash) \
      --fish <($out/bin/crush completion fish) \
      --zsh <($out/bin/crush completion zsh)
  '';

  meta = {
    description = "Glamourous AI coding agent for your favourite terminal";
    homepage = "https://github.com/charmbracelet/crush";
    changelog = "https://github.com/charmbracelet/crush/releases/tag/v${version}";
    license = lib.licenses.fsl11Mit;
    maintainers = with lib.maintainers; [
      x123
      malik
      davinci42
    ];
    mainProgram = "crush";
  };
}
