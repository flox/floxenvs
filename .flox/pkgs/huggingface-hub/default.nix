{
  lib,
  fetchFromGitHub,
  python3Packages,
}:

let
  data = builtins.fromJSON (builtins.readFile ./hashes.json);
in
python3Packages.toPythonApplication (
  python3Packages.huggingface-hub.overridePythonAttrs (old: {
    version = data.version;
    src = fetchFromGitHub {
      owner = "huggingface";
      repo = "huggingface_hub";
      tag = "v${data.version}";
      hash = data.srcHash;
    };

    # huggingface_hub 1.17.0 bumped its `click>=8.4.0` floor, but nixpkgs
    # still ships click 8.3.1. The 8.4.0 release is typing/cosmetic only, so
    # 8.3.1 works fine at runtime — relax the constraint to unblock the build.
    pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "click" ];
  })
)
