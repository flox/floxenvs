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

    # nixpkgs lags two upstream dependency floors that huggingface_hub bumped:
    #   - click>=8.4.0 (1.17.0): nixpkgs ships 8.3.1; the 8.4.0 release is
    #     typing/cosmetic only, so 8.3.1 works fine at runtime.
    #   - hf-xet>=1.5.1 (1.19.0): nixpkgs ships 1.4.3; hf-xet is the optional
    #     Xet accelerated-transfer backend and the older client is compatible
    #     (huggingface_hub also degrades gracefully without it).
    # Relax both constraints to unblock the pythonRuntimeDepsCheck.
    pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [
      "click"
      "hf-xet"
    ];
  })
)
