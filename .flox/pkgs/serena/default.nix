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
  # Discovered iteratively in Task 3 — start empty.
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
      # Sdist deps that don't declare a build-system in their
      # pyproject — uv2nix builds them without setuptools.
      proxy-tools = addSetuptools prev.proxy-tools;

      # Git-sourced: uv doesn't capture the package's declared
      # build-system requirements in the lockfile, so uv2nix
      # builds it without hatchling available.
      serena-agent = addHatchling prev.serena-agent;
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

  venv = pythonSet.mkVirtualEnv "serena-env"
    workspace.deps.default;

in
venv.overrideAttrs (old: {
  pname = "serena";
  version =
    let
      pyproject = lib.importTOML ./pyproject.toml;
      src = pyproject.tool.uv.sources.serena-agent;
    in
    lib.removePrefix "v" src.tag;

  passthru = (old.passthru or { }) // {
    python = python313;
  };

  meta = {
    description =
      "MCP toolkit for coding agents — IDE-grade semantic tools";
    homepage = "https://github.com/oraios/serena";
    license = lib.licenses.mit;
    mainProgram = "serena";
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
})
