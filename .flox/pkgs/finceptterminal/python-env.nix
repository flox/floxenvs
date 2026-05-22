{
  lib,
  python311,
  callPackage,
  fetchFromGitHub,
  portaudio,
  qt6,
  libxkbcommon,
  # pyproject-nix / uv2nix / pyproject-build-systems are optionally
  # forwarded by callers that have them as flake inputs. When absent
  # (e.g. `flox publish` invokes callPackage from bare nixpkgs), we
  # fall back to fetchFromGitHub-pinned versions below. Hashes here
  # MUST match flake.lock — see `jq '.nodes' flake.lock`.
  pyproject-nix ? null,
  uv2nix ? null,
  pyproject-build-systems ? null,
}:

let
  # Bootstrap fallback: when the caller did not supply the three
  # uv2nix-family flake inputs, fetch them by pinned rev. The hashes
  # are kept in sync with flake.lock; updating one requires updating
  # the other (a follow-up task could derive these from flake.lock
  # via jq in upgrade.sh).
  pyproject-nix-resolved =
    if pyproject-nix != null then
      pyproject-nix
    else
      import (fetchFromGitHub {
        owner = "pyproject-nix";
        repo = "pyproject.nix";
        rev = "a228447c3e179d477c1b6246ef3efa8cfe3c469a";
        hash = "sha256-GSKXTAnFqRAMlZkJrIPcQMYf+lpMr66K3i60mB9STvc=";
      }) { inherit lib; };

  uv2nix-resolved =
    if uv2nix != null then
      uv2nix
    else
      import
        (fetchFromGitHub {
          owner = "pyproject-nix";
          repo = "uv2nix";
          rev = "69aec536f6d1acc415ed2e20299312802aba98c6";
          hash = "sha256-P1LHCRdYpdtHAEzuEsNHrI6d9mVPl5a2fyFDZGHNVbI=";
        })
        {
          pyproject-nix = pyproject-nix-resolved;
          inherit lib;
        };

  pyproject-build-systems-resolved =
    if pyproject-build-systems != null then
      pyproject-build-systems
    else
      import
        (fetchFromGitHub {
          owner = "pyproject-nix";
          repo = "build-system-pkgs";
          rev = "ffaa2161dd5d63e0e94591f86b54fc239660fb2e";
          hash = "sha256-qapCOQmR++yZSY43dzrp3wCrkOTLpod+ONtJWBk6iKU=";
        })
        {
          pyproject-nix = pyproject-nix-resolved;
          uv2nix = uv2nix-resolved;
          inherit lib;
        };

  workspace = uv2nix-resolved.lib.workspace.loadWorkspace {
    workspaceRoot = ./python;
  };

  # Prefer wheels — most deps publish manylinux/macosx wheels and skipping
  # sdist builds for them saves a lot of native-build pain.
  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  # Helper: pyproject.nix tags wheel-built packages with
  # `passthru.format == "wheel"`. We use this to short-circuit
  # overrides that would otherwise inject build-system deps the
  # wheel doesn't need.
  isWheel = attrs: (attrs.passthru.format or "sdist") == "wheel";

  # Helper: most sdist-only packages in this workspace are pure-Python
  # but ship without a PEP 517 build-system declaration. uv.lock does
  # not record build-system metadata, so we inject setuptools as the
  # build backend ourselves. The `isWheel` guard makes the override
  # a no-op on platforms where uv2nix resolved to a wheel.
  needsSetuptools =
    final: prev: name:
    prev.${name}.overrideAttrs (
      old:
      if isWheel old then
        { }
      else
        {
          nativeBuildInputs =
            (old.nativeBuildInputs or [ ]) ++ (final.resolveBuildSystem { setuptools = [ ]; });
        }
    );

  # NVIDIA wheels bundle CUDA-toolchain-internal .so files that
  # depend on other NVIDIA libs (libnvJitLink, libcublas, libcusparse,
  # libmlx5, libibverbs, libucp, etc.) which aren't available outside
  # a CUDA toolchain install. Since the FinceptTerminal Python runtime
  # never invokes the GPU bits (the C++ Qt app is the user-facing
  # surface; Python is for analytics), missing CUDA-internal deps at
  # patchelf time are harmless.
  #
  # Rather than listing every nvidia-* package individually, we
  # discover them from `prev` and apply the override uniformly.
  ignoreNvidiaPatchelf =
    prev:
    let
      isNvidia = name: lib.hasPrefix "nvidia-" name;
      names = builtins.filter isNvidia (builtins.attrNames prev);
      mk = name: {
        ${name} = prev.${name}.overrideAttrs (_: {
          autoPatchelfIgnoreMissingDeps = true;
        });
      };
    in
    lib.foldl' lib.mergeAttrs { } (map mk names);

  # Overrides injected per-package as build failures surface. Each
  # entry should document *why* it's here.
  pyprojectOverrides =
    final: prev:
    (ignoreNvidiaPatchelf prev)
    // {
      # Pure-Python sdist-only packages missing a build-system declaration.
      gym = needsSetuptools final prev "gym";
      multitasking = needsSetuptools final prev "multitasking";
      ta = needsSetuptools final prev "ta";
      pandarallel = needsSetuptools final prev "pandarallel";
      sgmllib3k = needsSetuptools final prev "sgmllib3k";
      wikipedia = needsSetuptools final prev "wikipedia";
      randomname = needsSetuptools final prev "randomname";
      jsonpath = needsSetuptools final prev "jsonpath";
      py-vollib = needsSetuptools final prev "py-vollib";
      py-lets-be-rational = needsSetuptools final prev "py-lets-be-rational";

      # pyaudio: sdist-only, links against PortAudio at build and run time.
      pyaudio = prev.pyaudio.overrideAttrs (
        old:
        if isWheel old then
          { buildInputs = (old.buildInputs or [ ]) ++ [ portaudio ]; }
        else
          {
            buildInputs = (old.buildInputs or [ ]) ++ [ portaudio ];
            nativeBuildInputs =
              (old.nativeBuildInputs or [ ])
              ++ (final.resolveBuildSystem {
                setuptools = [ ];
                wheel = [ ];
              });
          }
      );

      # PySide6 wheels ship precompiled .so files that link against the
      # system Qt 6 — auto-patchelf can't find libQt6Core/libQt6Gui/etc.
      # We inject the matching nixpkgs Qt 6 libs so the runtime closure
      # is complete. libxkbcommon covers a separate xkb plugin dep.
      #
      # dontWrapQtApps disables nixpkgs's Qt-wrapper hook that would
      # otherwise fail with "this derivation depends on qtbase, but no
      # wrapping behavior was specified" — the wheel is a Python pkg
      # not a Qt application, so the auto-wrapping doesn't apply.
      pyside6-essentials = prev.pyside6-essentials.overrideAttrs (old: {
        dontWrapQtApps = true;
        buildInputs =
          (old.buildInputs or [ ])
          ++ (with qt6; [
            qtbase
            qtdeclarative
            qtmultimedia
            qtwebsockets
            qtwayland
            qtsvg
            qttools
          ])
          ++ [ libxkbcommon ];
      });
      pyside6-addons = prev.pyside6-addons.overrideAttrs (old: {
        dontWrapQtApps = true;
        buildInputs =
          (old.buildInputs or [ ])
          ++ (with qt6; [
            qtbase
            qtdeclarative
            qtmultimedia
            qtwebsockets
            qtwayland
            qtsvg
            qttools
          ])
          ++ [ libxkbcommon ];
      });

      # All nvidia-* packages are handled by ignoreNvidiaPatchelf above
      # (applied via `(ignoreNvidiaPatchelf prev) // { ... }`). Explicit
      # nvidia-* entries below would override that; we don't need any.
    };

  pythonSet =
    (callPackage pyproject-nix-resolved.build.packages {
      python = python311;
    }).overrideScope
      (
        lib.composeManyExtensions [
          pyproject-build-systems-resolved.overlays.wheel
          overlay
          pyprojectOverrides
        ]
      );
in
pythonSet.mkVirtualEnv "finceptterminal-python-env" workspace.deps.default
