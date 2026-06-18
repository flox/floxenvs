{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "flox-ai";
  version = "0.6.0";

  src = ./.;

  vendorHash = "sha256-+DbnT1T+fkwi8lfSmvCeKpqcyP7msaM2R1O1wXETip0=";

  meta = {
    description = "Flox-native config management for Claude Code CLI";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "flox-ai";
  };
}
