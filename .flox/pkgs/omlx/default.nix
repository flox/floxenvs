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

  # Per-package overrides for sdist builds that uv2nix's
  # default build-systems overlay doesn't fully resolve.
  pyprojectOverrides = final: prev:
    let
      addSetuptools = pkg:
        pkg.overrideAttrs (old: {
          nativeBuildInputs = (old.nativeBuildInputs or [ ])
            ++ final.resolveBuildSystem { setuptools = [ ]; };
        });
      sitePackages = "lib/python3.13/site-packages";
    in
    {
      # Git-sourced packages: uv doesn't capture their declared
      # build-system requirements in the lockfile, so uv2nix
      # builds them without setuptools available.
      dflash-mlx = addSetuptools prev.dflash-mlx;
      mlx-audio = addSetuptools prev.mlx-audio;
      mlx-embeddings = addSetuptools prev.mlx-embeddings;
      mlx-lm = addSetuptools prev.mlx-lm;
      mlx-vlm = addSetuptools prev.mlx-vlm;
      omlx = addSetuptools prev.omlx;

      # PyPI sdist packages that lack a build-system declaration.
      docopt = addSetuptools prev.docopt;
      webrtcvad = addSetuptools prev.webrtcvad;

      # The mlx wheel has core.cpython-313-darwin.so with
      # `@loader_path/lib/libmlx.dylib`, but libmlx ships in the
      # separate mlx-metal package. uv2nix's mkVirtualEnv merges
      # both via symlinks — but @loader_path resolves through the
      # symlink to mlx's store path, where mlx/lib/ doesn't exist.
      # Mirror mlx-metal's mlx/lib/ into mlx's store path so the
      # dyld resolver finds it.
      mlx = prev.mlx.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          mkdir -p $out/${sitePackages}/mlx/lib
          cp -r ${final.mlx-metal}/${sitePackages}/mlx/lib/. \
                $out/${sitePackages}/mlx/lib/
        '';
      });
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
