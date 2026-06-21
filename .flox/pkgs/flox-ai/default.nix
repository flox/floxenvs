{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "flox-ai";
  version = "0.8.0";

  src = ./.;

  vendorHash = "sha256-o/vXAZ8/yCNgjtpYkIoW07QsFsENSRP8I4xIJoGs470=";

  meta = {
    description = "Flox-native config management for Claude Code CLI";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "flox-ai";
  };
}
