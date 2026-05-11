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
  })
)
