{
  lib,
  python313,
  callPackage,
  yara,
}:

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

  pyprojectOverrides =
    final: prev:
    let
      addBuildSystem =
        buildSystem: pkg:
        pkg.overrideAttrs (old: {
          nativeBuildInputs =
            (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { "${buildSystem}" = [ ]; };
        });
      addSetuptools = addBuildSystem "setuptools";
      addHatchling = addBuildSystem "hatchling";
    in
    {
      # Git-sourced skillspector: uv doesn't capture the
      # declared build-system in the lockfile, and upstream
      # uses hatchling.
      skillspector = addHatchling prev.skillspector;

      # forbiddenfruit sdist needs setuptools (no build-system decl).
      forbiddenfruit = addSetuptools prev.forbiddenfruit;

      # yara-python sdist needs setuptools + the libyara
      # C library at build time.
      yara-python = (addSetuptools prev.yara-python).overrideAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ yara ];
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

  venv = pythonSet.mkVirtualEnv "skillspector-env" workspace.deps.default;

in
venv.overrideAttrs (old: {
  pname = "skillspector";
  version = (lib.importJSON ./hashes.json).version;

  passthru = (old.passthru or { }) // {
    python = python313;
  };

  meta = {
    description = "Security scanner for AI agent skills";
    homepage = "https://github.com/NVIDIA/SkillSpector";
    license = lib.licenses.asl20;
    mainProgram = "skillspector";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
})
