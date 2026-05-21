{
  lib,
  stdenv,
  fetchgit,
  cmake,
  ninja,
  pkg-config,
  qt6,
  openssl,
  callPackage,
}:

let
  hashes = builtins.fromJSON (builtins.readFile ./hashes.json);
  fc = callPackage ./fetchcontent.nix { };

  src = fetchgit {
    name = "fincept-terminal-${hashes.upstream.tag}";
    url = "https://github.com/Fincept-Corporation/FinceptTerminal.git";
    inherit (hashes.upstream) rev hash;
    fetchSubmodules = false;
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "finceptterminal";
  version = "${hashes.upstream.tag}+flox";

  inherit src;

  # The Qt project lives under fincept-qt/ inside the fetched tree.
  sourceRoot = "${finalAttrs.src.name}/fincept-qt";

  patches = [
    ./patches/0001-apppaths-root-env-var.patch
    ./patches/0002-python-setup-nix-sentinel.patch
  ];

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
    qt6.qttools
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtcharts
    qt6.qtwebsockets
    qt6.qtmultimedia
    qt6.qtspeech
    qt6.qtdeclarative
    openssl
  ];

  cmakeFlags = [
    # Accept any Qt 6.x — nixpkgs is on whichever 6.x is current, not
    # upstream's pinned 6.8.3. Upstream's escape hatch.
    "-DFINCEPT_QT_PIN_MODE=ANY"
    # We pre-fetch every FetchContent dep; never hit the network.
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DFETCHCONTENT_SOURCE_DIR_QXLSX=${fc.qxlsx}"
    "-DFETCHCONTENT_SOURCE_DIR_MD4C=${fc.md4c}"
    "-DFETCHCONTENT_SOURCE_DIR_QGEOVIEW=${fc.qgeoview}"
    "-DFETCHCONTENT_SOURCE_DIR_QTADS=${fc.qtads}"
    "-DFETCHCONTENT_SOURCE_DIR_ED25519=${fc.ed25519}"
    # QtADS derives its version from `git describe` against its own
    # repo. With FETCHCONTENT_SOURCE_DIR_QTADS pointing at our
    # fetchgit prefetch (no .git tree), the describe yields
    # "GIT-NOTFOUND" and CMake rejects it as a malformed version.
    # The escape hatch: pre-set ADS_VERSION (upstream pins QtADS at
    # rev 87cffe5d, tagged 4.5.0 — see comment near
    # FetchContent_Declare(QtADS) in fincept-qt/CMakeLists.txt).
    "-DADS_VERSION=4.5.0"
    # Skip the test suite — we don't ship the test binaries.
    "-DFINCEPT_BUILD_TESTS=OFF"
    # LTO slows the build massively; off for our (non-shipping) builds.
    "-DFINCEPT_ENABLE_LTO=OFF"
  ];

  # Apply the upstream-vendored QGeoView AGL-removal patch to the
  # prefetched QGeoView source. The upstream CMakeLists.txt invokes
  # this same script via FetchContent's PATCH_COMMAND, but with
  # FETCHCONTENT_SOURCE_DIR_* the PATCH_COMMAND is skipped — so we
  # run it ourselves. The Nix store is read-only by default; we
  # need to make the source dir writable first.
  #
  # On Linux the patch is a no-op (AGL is a macOS framework that
  # doesn't exist on Linux anyway), so a failure here on Linux is
  # cosmetic. We swallow the exit code with `|| true` rather than
  # gate on platform because it keeps the logic identical across
  # darwin.nix and linux.nix.
  preConfigure = ''
    if [ -f cmake/patches/qgeoview_remove_agl.cmake ]; then
      qgv_writable=$(mktemp -d)
      cp -R "${fc.qgeoview}"/. "$qgv_writable/"
      chmod -R u+w "$qgv_writable"
      cmake -DFILE="$qgv_writable/lib/CMakeLists.txt" \
            -P cmake/patches/qgeoview_remove_agl.cmake \
        || echo "warning: QGeoView AGL patch failed (Linux is unaffected)"
      # Point the CMake flag at the writable copy.
      cmakeFlagsArray+=(-DFETCHCONTENT_SOURCE_DIR_QGEOVIEW="$qgv_writable")
    fi

    # QtADS's root CMakeLists only adds cmake/modules to
    # CMAKE_MODULE_PATH inside the `if(NOT ADS_VERSION)` branch. We
    # set ADS_VERSION (see comment in common.nix cmakeFlags) which
    # skips that branch — but src/CMakeLists.txt still does
    # `include(Versioning)`, which then can't find the module.
    # Make a writable copy and prepend the module-path setup
    # unconditionally.
    qtads_writable=$(mktemp -d)
    cp -R "${fc.qtads}"/. "$qtads_writable/"
    chmod -R u+w "$qtads_writable"
    sed -i '1i list(APPEND CMAKE_MODULE_PATH "''${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules")' \
      "$qtads_writable/CMakeLists.txt"
    cmakeFlagsArray+=(-DFETCHCONTENT_SOURCE_DIR_QTADS="$qtads_writable")
  '';

  # No installPhase here — linux.nix and darwin.nix each provide
  # their own (the platforms produce very different artifacts:
  # Linux ELF vs macOS .app bundle).
})
