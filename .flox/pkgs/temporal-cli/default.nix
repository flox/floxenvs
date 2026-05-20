{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  writableTmpDirAsHomeHook,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash vendorHash;
in
buildGoModule (finalAttrs: {
  pname = "temporal-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "temporalio";
    repo = "cli";
    tag = "v${version}";
    hash = srcHash;
  };

  inherit vendorHash;

  nativeBuildInputs = [ installShellFiles ];

  subPackages = [ "cmd/temporal" ];

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/temporalio/cli/internal/temporalcli.Version=${version}"
  ];

  # Upstream tests fail under macOS x86_64 (Rosetta 2).
  doCheck = !(
    stdenv.hostPlatform.isDarwin
    && stdenv.hostPlatform.isx86_64
  );

  nativeCheckInputs = [ writableTmpDirAsHomeHook ];

  postInstall = lib.optionalString (
    stdenv.buildPlatform.canExecute stdenv.hostPlatform
  ) ''
    installShellCompletion --cmd temporal \
      --bash <($out/bin/temporal completion bash) \
      --fish <($out/bin/temporal completion fish) \
      --zsh  <($out/bin/temporal completion zsh)
  '';

  __darwinAllowLocalNetworking = true;

  meta = {
    description =
      "Temporal CLI — server, workflow management, "
      + "embedded dev server + Web UI";
    homepage = "https://docs.temporal.io/cli";
    changelog =
      "https://github.com/temporalio/cli/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "temporal";
    platforms = lib.platforms.unix;
  };
})
