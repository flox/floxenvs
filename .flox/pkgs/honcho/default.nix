{
  lib,
  python313,
  callPackage,
}:

let
  # Same uv2nix wiring as basic-memory: source the three
  # libraries from their sibling wrapper packages.
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

  # Honcho's upstream pyproject ships no [build-system] — it's
  # an "app" the upstream Docker COPYs into /app and runs from
  # there. To install it via uv2nix:
  #   1. relocate migrations/ + alembic.ini under src/ so they
  #      survive the site-packages install,
  #   2. inject a minimal setuptools backend with package-data,
  #   3. include the src package via packages.find
  #      (src/__init__.py is already present upstream).
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
      # honcho-ai is sourced from a git subdirectory. Its
      # pyproject declares setuptools + wheel in [build-system],
      # but `uv lock` against a git source doesn't capture
      # those, so uv2nix has to inject them.
      honcho-ai = addSetuptools prev.honcho-ai;

      honcho = prev.honcho.overrideAttrs (old: {
        nativeBuildInputs =
          (old.nativeBuildInputs or [ ])
          ++ final.resolveBuildSystem {
            setuptools = [ ];
          };
        postPatch = (old.postPatch or "") + ''
          # Move alembic assets under src/ so they ship as
          # package data inside site-packages.
          mv migrations src/migrations
          mv alembic.ini src/alembic.ini

          cat > MANIFEST.in <<'EOF'
recursive-include src/migrations *
include src/alembic.ini
EOF

          cat >> pyproject.toml <<'EOF'

[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[tool.setuptools]
include-package-data = true

[tool.setuptools.packages.find]
where = ["."]
include = ["src", "src.*"]
EOF
        '';
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

  venv = pythonSet.mkVirtualEnv "honcho-env" workspace.deps.default;
in
venv.overrideAttrs (old: {
  pname = "honcho";
  inherit version;

  passthru = (old.passthru or { }) // {
    python = python313;
  };

  # Drop in three wrapper scripts that point at the venv's
  # uvicorn / python / alembic. The wrappers are stored under
  # ./wrappers/ with an `@OUT@` placeholder that gets replaced
  # with the real $out path here.
  postInstall = (old.postInstall or "") + ''
    for name in honcho-server honcho-deriver honcho-migrate; do
      install -m 0755 ${./wrappers}/$name $out/bin/$name
      substituteInPlace $out/bin/$name --replace-fail "@OUT@" "$out"
    done
  '';

  meta = {
    description = "Self-hostable memory infrastructure for stateful agents.";
    homepage = "https://github.com/plastic-labs/honcho";
    license = lib.licenses.agpl3Only;
    mainProgram = "honcho-server";
    # Heavy ML deps (lancedb, pyarrow, scikit-learn) typically
    # ship wheels only for the standard three-platform target.
    # x86_64-darwin is excluded for the same reason as
    # basic-memory.
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
