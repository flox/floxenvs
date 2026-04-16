{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "claude-managed";
  version = "0.2.0";

  src = ./.;

  vendorHash = null;

  meta = {
    description =
      "Flox-native config management for Claude Code CLI";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "claude-managed";
  };
}
