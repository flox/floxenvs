{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash vendorHash;
in
buildGoModule (finalAttrs: {
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
