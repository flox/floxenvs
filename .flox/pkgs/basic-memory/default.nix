{
  lib,
  python313,
  callPackage,
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

  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version;

  # Per-package overrides for sdist builds that uv2nix's
  # default build-systems overlay doesn't fully resolve.
  pyprojectOverrides =
    final: prev:
    let
      addSetuptools =
        pkg:
        pkg.overrideAttrs (old: {
          nativeBuildInputs =
            (old.nativeBuildInputs or [ ]) ++ final.resolveBuildSystem { setuptools = [ ]; };
        });
    in
    {
      # PyPI sdist packages that lack a build-system declaration.
      pybars3 = addSetuptools prev.pybars3;
      pymeta3 = addSetuptools prev.pymeta3;

      # basic-memory is sourced from git. uv lock doesn't capture
      # its declared build-system requires (hatchling +
      # uv-dynamic-versioning), so uv2nix needs them injected. The
      # bypass env skips the git-history probe that
      # uv-dynamic-versioning would otherwise run.
      basic-memory = prev.basic-memory.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [ ])
          ++ final.resolveBuildSystem {
            hatchling = [ ];
            uv-dynamic-versioning = [ ];
          };
        env = (old.env or { }) // {
          UV_DYNAMIC_VERSIONING_BYPASS = version;
        };
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

  venv = pythonSet.mkVirtualEnv "basic-memory-env" workspace.deps.default;
in
venv.overrideAttrs (old: {
  pname = "basic-memory";
  inherit version;

  passthru = (old.passthru or { }) // {
    python = python313;
  };

  meta = {
    description = "Markdown-based knowledge management with an MCP server for AI assistants.";
    homepage = "https://github.com/basicmachines-co/basic-memory";
    license = lib.licenses.agpl3Plus;
    mainProgram = "basic-memory";
    # x86_64-darwin is excluded: onnxruntime ships no compatible
    # wheel for the platform (and nixpkgs is dropping support in
    # 26.05 anyway). fastembed pulls onnxruntime in.
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
