{
  lib,
  python311,
  callPackage,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
}:

let
  workspace = uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = ./python;
  };

  # Prefer wheels — most deps publish manylinux/macosx wheels and skipping
  # sdist builds for them saves a lot of native-build pain.
  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  # Overrides injected per-package as build failures surface. Keep the
  # list short; each entry should document *why* it's here.
  pyprojectOverrides = _final: _prev: {
  };

  pythonSet =
    (callPackage pyproject-nix.build.packages {
      python = python311;
    }).overrideScope
      (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          overlay
          pyprojectOverrides
        ]
      );
in
pythonSet.mkVirtualEnv "finceptterminal-python-env" workspace.deps.default
