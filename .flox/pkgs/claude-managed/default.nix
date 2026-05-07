{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "claude-managed";
  version = "0.3.0";

  src = ./.;

  vendorHash = "sha256-g+yaVIx4jxpAQ/+WrGKxhVeliYx7nLQe/zsGpxV4Fn4=";

  meta = {
    description = "Flox-native config management for Claude Code CLI";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "claude-managed";
  };
}
