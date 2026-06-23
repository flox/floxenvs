{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "flox-ai";
  # Single source of truth: the VERSION file, also embedded into the Go
  # binary (see main.go //go:embed VERSION) so both report the same value.
  version = lib.fileContents ./VERSION;

  src = ./.;

  vendorHash = "sha256-o/vXAZ8/yCNgjtpYkIoW07QsFsENSRP8I4xIJoGs470=";

  meta = {
    description = "Flox-native config management for Claude Code CLI";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "flox-ai";
  };
}
