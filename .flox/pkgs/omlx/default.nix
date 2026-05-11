{
  lib,
  stdenv,
  python313,
  callPackage,
}:

let
  manifestLock = builtins.fromJSON
    (builtins.readFile ../../.flox/env/manifest.lock);

  system = stdenv.hostPlatform.system;

  getStorePath = name:
    let
      pkg = lib.findFirst
        (p: p.install_id == name && p.system == system) null
        manifestLock.packages;
    in
    assert (pkg != null)
      || (throw "package '${name}' not found in manifest.lock for ${system}");
    builtins.storePath pkg.outputs.out;

  pyproject-nix-pkg = getStorePath "pyproject-nix";
  uv2nix-pkg = getStorePath "uv2nix";
  pyproject-build-systems-pkg =
    getStorePath "pyproject-build-systems";

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

  pythonSet =
    (callPackage pyproject-nix-lib.build.packages {
      python = python313;
    }).overrideScope
      (lib.composeManyExtensions [
        build-systems-overlays.default
        overlay
      ]);

  venv = pythonSet.mkVirtualEnv "omlx-env"
    workspace.deps.default;

in
venv.overrideAttrs (old: {
  pname = "omlx";
  version =
    let
      pyproject = lib.importTOML ./pyproject.toml;
      src = pyproject.tool.uv.sources.omlx;
    in
    lib.removePrefix "v" src.tag;

  passthru = (old.passthru or { }) // {
    python = python313;
  };

  meta = {
    description =
      "LLM inference server, optimized for your Mac";
    homepage = "https://github.com/jundot/omlx";
    license = lib.licenses.asl20;
    mainProgram = "omlx";
    platforms = [ "aarch64-darwin" ];
  };
})
