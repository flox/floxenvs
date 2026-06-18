{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "flox-ai";
  version = "0.9.0";

  src = ./.;

  vendorHash = "sha256-jFYAXgwsWwTEeY1xHW/gtwF1KaJc7Vx5GTKEl12Zah4=";

  meta = {
    description = "Flox-native config management for Claude Code CLI";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "flox-ai";
  };
}
