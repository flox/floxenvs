{
  lib,
  python313,
  callPackage,
}:

# mergekit-cuda: mergekit with the default PyPI torch wheels,
# which bundle the CUDA runtime via the nvidia-* packages. The
# CPU-only variant lives in ../mergekit; keep the two wrappers'
# pinned tags in lockstep when upgrading.

let
  # Build the three uv2nix Nix libraries directly from their
  # sibling wrapper packages. Each wrapper is a pure-Nix
  # derivation that fetches the upstream repo via
  # fetchFromGitHub and exports the source under $out/<libname>/.
  pyproject-nix-pkg = callPackage ../pyproject-nix { };
  uv2nix-pkg = callPackage ../uv2nix { };
  pyproject-build-systems-pkg = callPackage ../pyproject-build-systems { };

  pyproject-nix-lib = import "${pyproject-nix-pkg}/pyproject-nix" {
    inherit lib;
  };

  uv2nix-module = import "${uv2nix-pkg}/uv2nix" {
    inherit lib;
    pyproject-nix = pyproject-nix-lib;
  };

  build-systems-overlays = import "${pyproject-build-systems-pkg}/pyproject-build-systems" {
    inherit lib;
    uv2nix = uv2nix-module;
    pyproject-nix = pyproject-nix-lib;
  };

  workspace = uv2nix-module.lib.workspace.loadWorkspace {
    workspaceRoot = ./.;
  };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version;

  # Per-package overrides for sdist builds that uv2nix's
  # default build-systems overlay doesn't fully resolve.
  pyprojectOverrides =
    final: prev:
    let
      # torch and the nvidia-* runtime wheels cross-reference
      # CUDA libraries that live in sibling wheels (and
      # libcuda.so.1 comes from the host driver). torch loads
      # them at runtime via its own preload logic, so
      # auto-patchelf's unresolved-dependency errors are
      # expected — silence them instead of failing the build.
      ignoreMissing =
        pkg:
        pkg.overrideAttrs (_: {
          autoPatchelfIgnoreMissingDeps = true;
        });
      cudaWheels = [
        "torch"
        "triton"
        "nvidia-cublas"
        "nvidia-cuda-cupti"
        "nvidia-cuda-nvrtc"
        "nvidia-cuda-runtime"
        "nvidia-cudnn-cu13"
        "nvidia-cufft"
        "nvidia-cufile"
        "nvidia-curand"
        "nvidia-cusolver"
        "nvidia-cusparse"
        "nvidia-cusparselt-cu13"
        "nvidia-nccl-cu13"
        "nvidia-nvjitlink"
        "nvidia-nvshmem-cu13"
        "nvidia-nvtx"
      ];
    in
    lib.genAttrs cudaWheels (name: ignoreMissing prev.${name})
    // {
      # mergekit is sourced from git. uv lock doesn't capture its
      # declared build-system requires (setuptools), so uv2nix
      # builds it without setuptools available.
      mergekit = prev.mergekit.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
      });
    };

  pythonSet =
    (callPackage pyproject-nix-lib.build.packages {
      python = python313;
    }).overrideScope
      (
        lib.composeManyExtensions [
          build-systems-overlays.default
          overlay
          pyprojectOverrides
        ]
      );

  venv = pythonSet.mkVirtualEnv "mergekit-cuda-env" workspace.deps.default;
in
venv.overrideAttrs (old: {
  pname = "mergekit-cuda";
  inherit version;

  passthru = (old.passthru or { }) // {
    python = python313;
  };

  meta = {
    description = "Tools for merging pre-trained large language models, with CUDA-enabled torch.";
    homepage = "https://github.com/arcee-ai/mergekit";
    license = lib.licenses.lgpl3Only;
    mainProgram = "mergekit-yaml";
    # Linux only: the CUDA-bundled torch wheels exist solely for
    # linux; darwin users want ../mergekit (CPU).
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
