{
  lib,
  python313,
  callPackage,
}:

let
  # Build the three uv2nix Nix libraries directly from their
  # sibling wrapper packages.
  pyproject-nix-pkg = callPackage ../pyproject-nix { };
  uv2nix-pkg = callPackage ../uv2nix { };
  pyproject-build-systems-pkg =
    callPackage ../pyproject-build-systems { };

  pyproject-nix-lib =
    import "${pyproject-nix-pkg}/pyproject-nix" {
      inherit lib;
    };

  uv2nix-module =
    import "${uv2nix-pkg}/uv2nix" {
      inherit lib;
      pyproject-nix = pyproject-nix-lib;
    };

  build-systems-overlays =
    import "${pyproject-build-systems-pkg}/pyproject-build-systems" {
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

  # Per-package overrides for sdist builds whose build-system
  # declaration uv2nix's default overlay doesn't fully resolve.
  pyprojectOverrides = final: prev:
    let
      addSetuptools = pkg:
        pkg.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ])
            ++ final.resolveBuildSystem { setuptools = [ ]; };
        });
      addHatchling = pkg:
        pkg.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ])
            ++ final.resolveBuildSystem { hatchling = [ ]; };
        });
    in
    {
      # sdist that depends on setuptools at build time but
      # doesn't declare it in build-system.requires.
      dbgpu = addSetuptools prev.dbgpu;

      # Git-sourced: uv doesn't capture the package's declared
      # build-system requirements in the lockfile, so uv2nix
      # builds it without hatchling available.
      whichllm = addHatchling prev.whichllm;
    };

  pythonSet =
    (callPackage pyproject-nix-lib.build.packages {
      python = python313;
    }).overrideScope
      (lib.composeManyExtensions [
        build-systems-overlays.default
        overlay
        pyprojectOverrides
      ]);

  venv = pythonSet.mkVirtualEnv "whichllm-env"
    workspace.deps.default;

in
venv.overrideAttrs (old: {
  pname = "whichllm";
  version =
    let
      pyproject = lib.importTOML ./pyproject.toml;
      src = pyproject.tool.uv.sources.whichllm;
    in
    lib.removePrefix "v" src.tag;

  passthru = (old.passthru or { }) // {
    python = python313;
  };

  meta = {
    description =
      "Find the best LLM that runs on your hardware";
    homepage = "https://github.com/Andyyyy64/whichllm";
    license = lib.licenses.mit;
    mainProgram = "whichllm";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
})
