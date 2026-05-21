{ fetchgit }:

let
  hashes = (builtins.fromJSON (builtins.readFile ./hashes.json)).fetchcontent;

  mk =
    name: spec:
    fetchgit {
      name = "fincept-fc-${name}";
      inherit (spec) url rev hash;
      deepClone = false;
      leaveDotGit = false;
      fetchSubmodules = false;
    };
in
{
  qxlsx = mk "qxlsx" hashes.qxlsx;
  md4c = mk "md4c" hashes.md4c;
  qgeoview = mk "qgeoview" hashes.qgeoview;
  qtads = mk "qtads" hashes.qtads;
  ed25519 = mk "ed25519" hashes.ed25519;
}
