{
  lib,
  stdenv,
  buildGoModule,
  fetchFromGitHub,
  fetchurl,
  go,
  installShellFiles,
  writableTmpDirAsHomeHook,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash vendorHash;

  # temporal-cli >= 1.7.1 sets `go 1.26.4` in go.mod, but the pinned
  # catalog still ships Go 1.26.2 and buildGoModule runs with
  # GOTOOLCHAIN=local, so the build fails the version gate. Bump just
  # the toolchain used for this package (a patch-level source swap)
  # until the base nixpkgs advances past 1.26.4.
  go_1_26_4 = go.overrideAttrs (old: {
    version = "1.26.4";
    src = fetchurl {
      url = "https://go.dev/dl/go1.26.4.src.tar.gz";
      hash = "sha256-T2aKMvv8ETLmqIH7lowvHa2mMUkqM5IRc1+7JVpCYC0=";
    };
  });
in
(buildGoModule.override { go = go_1_26_4; }) (finalAttrs: {
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
