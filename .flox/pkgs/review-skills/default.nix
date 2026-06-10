{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "review-skills";
  version = "0.1.0";

  src = ./.;

  vendorHash = null;

  meta = {
    description = "Unified 0-100 quality score for Claude skills & agents";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "review-skills";
  };
}
