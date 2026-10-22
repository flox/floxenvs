{
  go_1_27,
  fetchurl,
}:

# nixpkgs' go_1_27 (patches, bootstrap, meta) with only the source bumped.

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
in
go_1_27.overrideAttrs (finalAttrs: _prev: {
  inherit (versionData) version;

  src = fetchurl {
    url = "https://go.dev/dl/go${finalAttrs.version}.src.tar.gz";
    inherit (versionData) hash;
  };
})
