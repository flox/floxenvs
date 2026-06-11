{
  lib,
  buildGoModule,
  fetchFromGitHub,
  fetchurl,
  go,
  versionCheckHook,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash vendorHash;

  # temporal >= 1.31.1 sets `go 1.26.4` in go.mod, but the pinned
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
  pname = "temporal";
  inherit version;

  src = fetchFromGitHub {
    owner = "temporalio";
    repo = "temporal";
    tag = "v${version}";
    hash = srcHash;
  };

  inherit vendorHash;

  excludedPackages = [ "./build" ];

  env.CGO_ENABLED = 0;

  tags = [ "test_dep" ];
  ldflags = [
    "-s"
    "-w"
  ];

  # Upstream's integration tests are huge and not relevant for
  # the dev-server use case Flox cares about.
  doCheck = false;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share
    cp -r ./schema $out/share/

    install -Dm755 "$GOPATH/bin/server" -T \
      $out/bin/temporal-server
    install -Dm755 "$GOPATH/bin/cassandra" -T \
      $out/bin/temporal-cassandra-tool
    install -Dm755 "$GOPATH/bin/sql" -T \
      $out/bin/temporal-sql-tool
    install -Dm755 "$GOPATH/bin/tdbg" -T $out/bin/tdbg

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";
  doInstallCheck = true;

  meta = {
    description =
      "Temporal orchestration platform (server + tools)";
    homepage = "https://temporal.io";
    changelog =
      "https://github.com/temporalio/temporal/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "temporal-server";
    platforms = lib.platforms.unix;
  };
})
