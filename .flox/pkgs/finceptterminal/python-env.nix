{
  lib,
  python311,
  callPackage,
  pyproject-nix,
  uv2nix,
  pyproject-build-systems,
  portaudio,
  qt6,
  libxkbcommon,
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
      pyside6-essentials = prev.pyside6-essentials.overrideAttrs (old: {
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
    (callPackage pyproject-nix.build.packages {
      python = python311;
    }).overrideScope
      (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.wheel
          overlay
          pyprojectOverrides
        ]
      );
in
pythonSet.mkVirtualEnv "finceptterminal-python-env" workspace.deps.default
