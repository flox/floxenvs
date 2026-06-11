{
  lib,
  buildGoModule,
}:

buildGoModule {
  pname = "review-skills";
  version = "0.2.0";

  src = ./.;

  vendorHash = "sha256-g+yaVIx4jxpAQ/+WrGKxhVeliYx7nLQe/zsGpxV4Fn4=";

  meta = {
    description = "Unified 0-100 quality score for Claude skills & agents";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
    mainProgram = "review-skills";
  };
}
