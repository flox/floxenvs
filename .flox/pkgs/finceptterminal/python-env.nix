{
  lib,
  stdenv,
  python311,
  callPackage,
  portaudio,
  qt6,
  libxkbcommon,
}:

let
  # Build the three uv2nix Nix libraries directly from their
  # sibling wrapper packages. Each wrapper is a fixed-output
  # derivation that fetches the upstream repo via fetchFromGitHub
  # and exports the source under $out/<libname>/. This matches the
  # serena / basic-memory pattern and works uniformly under
  # `flox build` and `flox publish` (neither of which pass flake
  # inputs).
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
  # a CUDA toolchain install. The Linux torch wheel ships the same
  # CUDA-linked .so files inside its own package (libtorch_cuda.so,
  # libtorch_cuda_linalg.so, libtorch_nvshmem.so, libtorch_python.so).
  # Since the FinceptTerminal Python runtime never invokes the GPU
  # bits (the C++ Qt app is the user-facing surface; Python is for
  # analytics), missing CUDA-internal deps at patchelf time are
  # harmless on both nvidia-* and torch-family packages.
  #
  # Rather than listing every offender individually, we discover them
  # from `prev` and apply the override uniformly.
  ignoreCudaPatchelf =
    prev:
    let
      isCuda =
        name:
        lib.hasPrefix "nvidia-" name || name == "torch" || name == "torchaudio" || name == "torchvision";
      names = builtins.filter isCuda (builtins.attrNames prev);
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
    (ignoreCudaPatchelf prev)
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
        # Every .abi3.so in the wheel dlopens libshiboken6.abi3.so.6.8,
        # which ships in the sibling shiboken6 package. Same
        # cross-package issue as pyside6-addons — the merged venv
        # site-packages resolves it at runtime.
        autoPatchelfIgnoreMissingDeps = true;
        buildInputs =
          (old.buildInputs or [ ])
          ++ (with qt6; [
            qtbase
            qtdeclarative
            qtmultimedia
            qtwebsockets
            qtsvg
            qttools
          ])
          # qtwayland / libxkbcommon are Linux-only — qtwayland.meta
          # explicitly excludes Darwin and libxkbcommon is X11 stack.
          ++ lib.optionals stdenv.hostPlatform.isLinux [
            qt6.qtwayland
            libxkbcommon
          ];
      });
      pyside6-addons = prev.pyside6-addons.overrideAttrs (old: {
        dontWrapQtApps = true;
        # The pyside6-addons wheel pulls in a long tail of optional Qt
        # modules (WebEngine, Nfc, Quick3D, Speech, Multimedia plugins)
        # whose bundled .so files reference cross-package libs
        # (libpyside6.abi3.so, libshiboken6.abi3.so), bundled Qt libs
        # the wheel ships at PySide6/Qt/lib/ but auto-patchelf doesn't
        # see, and a grab-bag of system libs (libXdamage, libXrandr,
        # libasound, libxshmfence, libpcsclite, libspeechd, …). The
        # venv resolves all of these at runtime via co-located libs
        # and standard LD search paths, so we suppress the
        # build-time auto-patchelf check uniformly.
        autoPatchelfIgnoreMissingDeps = true;
        buildInputs =
          (old.buildInputs or [ ])
          ++ (with qt6; [
            qtbase
            qtdeclarative
            qtmultimedia
            qtwebsockets
            qtsvg
            qttools
          ])
          ++ lib.optionals stdenv.hostPlatform.isLinux [
            qt6.qtwayland
            libxkbcommon
          ];
      });

      # All nvidia-* packages are handled by ignoreCudaPatchelf above
      # (applied via `(ignoreCudaPatchelf prev) // { ... }`). Explicit
      # nvidia-* entries below would override that; we don't need any.
    };

  pythonSet =
    (callPackage pyproject-nix-lib.build.packages {
      python = python311;
    }).overrideScope
      (
        lib.composeManyExtensions [
          build-systems-overlays.overlays.wheel
          overlay
          pyprojectOverrides
        ]
      );
in
# Sloppy wheels in the FinceptTerminal dep graph ship top-level
# files inside site-packages (LICENSE.txt, tests/ trees, etc.) that
# collide between packages. uv tolerates these because it links
# package-at-a-time; pyproject-nix's mkVirtualEnv merges all packages
# into one tree and refuses on non-identical file collisions. We
# allow first-wins for LICENSE/README/tests at site-packages root,
# which mirrors uv's de-facto behavior. mkVirtualenvFlags is rebuilt
# from finalAttrs.venvIgnoreCollisions automatically.
(pythonSet.mkVirtualEnv "finceptterminal-python-env" workspace.deps.default).overrideAttrs (old: {
  venvIgnoreCollisions = (old.venvIgnoreCollisions or [ ]) ++ [
    "lib/python3.11/site-packages/LICENSE*"
    "lib/python3.11/site-packages/README*"
    "lib/python3.11/site-packages/tests/*"
    "lib/python3.11/site-packages/tests"
  ];
})
