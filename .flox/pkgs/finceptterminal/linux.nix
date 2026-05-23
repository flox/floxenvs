{
  lib,
  stdenv,
  callPackage,
  qt6,
  libxkbcommon,
  xcb-util-cursor,
  fontconfig,
  dbus,
  libsecret,
  libGL,
  libGLU,
  wayland,
  expat,
  portaudio,
  openssl,
  uv,
  pythonEnv,
}:

let
  common = callPackage ./common.nix { };
in
common.overrideAttrs (old: {
  buildInputs = old.buildInputs ++ [
    qt6.qtwayland
    libxkbcommon
    xcb-util-cursor
    fontconfig
    dbus
    libsecret
    libGL
    libGLU
    wayland
    expat
    portaudio
  ];

  # We copy the binary directly out of $build_dir at installPhase
  # instead of letting cmake run its install step. Without this flag
  # the binary keeps cmake's BUILD_RPATH (which points back into
  # $build_dir/_deps/*), and stdenv's reference scan rejects it.
  # `CMAKE_BUILD_WITH_INSTALL_RPATH=ON` makes cmake bake the
  # install-tree RPATH straight into the build-tree binary, which is
  # exactly what we want here — and it costs nothing because we never
  # run the binary from the build dir.
  cmakeFlags = old.cmakeFlags ++ [
    "-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON"
  ];

  # We bypass CPack/IFW (that builds the upstream installer, not
  # what we want here) and install the binary + Qt plugins +
  # resources manually.
  #
  # nixpkgs's cmakeHook leaves cwd in the cmake build dir
  # (fincept-qt/build/) at installPhase time. The binary is in cwd
  # as ./FinceptTerminal; resource trees live one level up at
  # ../scripts, ../resources, ../translations. Upstream's
  # CMakeLists also copies scripts/ INTO the build dir during the
  # build (cf. the "Copying Python scripts to build output" line
  # in build logs), so we prefer the in-build-dir copies when
  # they exist.
  #
  # Note: this installPhase is intentionally minimal. Phase 7 (Task
  # 7.2) extends it with the pre-built install-dir layout; Phase 8
  # (Task 8.1) adds the bin/finceptterminal wrapper. For now we
  # produce a working unwrapped binary and the resource trees.
  installPhase = ''
    runHook preInstall

    src_root="$(realpath ..)"
    build_dir="$(pwd)"

    install -Dm755 "$build_dir/FinceptTerminal" \
      "$out/bin/.finceptterminal-unwrapped"

    # PythonRunner / ScriptCatalog resolve scripts via Qt's
    # QCoreApplication::applicationDirPath(), which returns the binary's
    # directory. The wrapper exec's the unwrapped binary out of
    # $out/bin/, so we mirror scripts/ + resources/ + translations/
    # there. Symlinks pointing into $out/share/finceptterminal/ keep
    # the deduplicated tree.
    if [ -d "$build_dir/scripts" ]; then
      cp -R "$build_dir/scripts" "$out/bin/"
    elif [ -d "$src_root/scripts" ]; then
      cp -R "$src_root/scripts" "$out/bin/"
    fi
    cp -R "$src_root/resources"    "$out/bin/" 2>/dev/null || true
    cp -R "$src_root/translations" "$out/bin/" 2>/dev/null || true

    # Qt plugins — copy the directories wrapQtAppsHook will then
    # patch into the binary's QT_PLUGIN_PATH.
    mkdir -p "$out/lib/qt-6/plugins"
    for plugin_dir in platforms wayland-shell-integration \
                      wayland-decoration-client wayland-graphics-integration-client \
                      tls imageformats iconengines \
                      mediaservice multimedia \
                      printsupport sqldrivers styles \
                      xcbglintegrations; do
      if [ -d "${qt6.qtbase}/lib/qt-6/plugins/$plugin_dir" ]; then
        cp -R "${qt6.qtbase}/lib/qt-6/plugins/$plugin_dir" \
              "$out/lib/qt-6/plugins/" || true
      fi
    done

    # Application resources (scripts/, resources/, translations).
    # These trees are what PythonRunner / ScriptCatalog scan at
    # runtime to discover analytics modules. Prefer the build-dir
    # copy (post-prune_scripts_junk) over the raw source for scripts.
    mkdir -p "$out/share/finceptterminal"
    if [ -d "$build_dir/scripts" ]; then
      cp -R "$build_dir/scripts" "$out/share/finceptterminal/"
    elif [ -d "$src_root/scripts" ]; then
      cp -R "$src_root/scripts" "$out/share/finceptterminal/"
    fi
    cp -R "$src_root/resources"    "$out/share/finceptterminal/" 2>/dev/null || true
    cp -R "$src_root/translations" "$out/share/finceptterminal/" 2>/dev/null || true

    # Desktop entry + icon for end users who want to wire it into
    # a window-manager launcher.
    install -Dm644 "$src_root/packaging/linux/fincept-terminal.desktop" \
      "$out/share/applications/fincept-terminal.desktop" 2>/dev/null || true

    # ── Task 7.2: pre-built install-dir layout ──────────────────
    # PythonSetupManager looks at $FINCEPT_INSTALL_DIR for its uv +
    # python + venv-numpy{1,2} state. We materialize the tree it
    # expects: a sentinel file (recognised by patch 0002), the uv
    # binary (kept for the rare 'uv pip list' verify path), a base
    # Python symlink, and venv-numpy{1,2} dirs each with a
    # bin/python3 symlink + a .packages_installed marker matching
    # the live requirements file's sha256 hash.
    install_dir="$out/share/finceptterminal/install-dir"
    mkdir -p "$install_dir/uv" \
             "$install_dir/python/nix-3.11/bin" \
             "$install_dir/venv-numpy2/bin" \
             "$install_dir/venv-numpy2/lib/python3.11" \
             "$install_dir/venv-numpy1/bin" \
             "$install_dir/venv-numpy1/lib/python3.11"

    touch "$install_dir/.fincept-nix-managed"
    ln -s ${lib.getExe uv} "$install_dir/uv/uv"

    ln -s ${pythonEnv}/bin/python3.11 \
          "$install_dir/python/nix-3.11/bin/python3"

    # venv-numpy2 — the primary venv. site-packages symlink gives the
    # patched runtime full access to the Nix-built closure.
    ln -s ${pythonEnv}/bin/python3.11 \
          "$install_dir/venv-numpy2/bin/python3"
    ln -s ${pythonEnv}/lib/python3.11/site-packages \
          "$install_dir/venv-numpy2/lib/python3.11/site-packages"

    # venv-numpy1 — the legacy NumPy-1.x path. We don't build a
    # separate closure for it (the workspace targets numpy 2.x only),
    # but PythonSetupManager checks for venv-numpy1's existence and
    # would attempt to bootstrap it if absent. Symlinking it at the
    # same closure satisfies the check without producing a useless
    # second build. Code paths that explicitly need numpy 1.x APIs
    # are rare in FinceptTerminal and surface at runtime, not here.
    ln -s ${pythonEnv}/bin/python3.11 \
          "$install_dir/venv-numpy1/bin/python3"
    ln -s ${pythonEnv}/lib/python3.11/site-packages \
          "$install_dir/venv-numpy1/lib/python3.11/site-packages"

    # Marker hashes — written by compute-marker-hash.sh to match what
    # upstream's PythonSetupManager::write_marker_hash would produce
    # on a fresh launch. The hash is sha256-hex of the live
    # requirements file. PythonSetupManager re-reads the file at
    # every launch and compares — if equal, venv_{1,2}_ready=true
    # and the setup wizard never appears.
    bash ${./python/compute-marker-hash.sh} \
      "$src_root/resources/requirements-numpy2.txt" \
      > "$install_dir/venv-numpy2/.packages_installed"
    if [ -f "$src_root/resources/requirements-numpy1.txt" ]; then
      bash ${./python/compute-marker-hash.sh} \
        "$src_root/resources/requirements-numpy1.txt" \
        > "$install_dir/venv-numpy1/.packages_installed"
    else
      cp "$install_dir/venv-numpy2/.packages_installed" \
         "$install_dir/venv-numpy1/.packages_installed"
    fi

    # ── Task 8.1: bin/finceptterminal wrapper ──────────────────
    # The unwrapped binary's runtime needs three env vars:
    #   FINCEPT_INSTALL_DIR — points at the install-dir tree above
    #     (so AppPaths::root() returns it; see patch 0001)
    #   QT_PLUGIN_PATH       — Qt plugins vendored into $out
    #   LD_LIBRARY_PATH      — runtime libs (portaudio, expat,
    #     openssl) that some Python extensions dlopen
    #
    # We re-export the user's existing values when set, so an
    # outer flox-include that overrides FINCEPT_DATA_DIR /
    # FINCEPT_INSTALL_DIR still wins.
    cat > "$out/bin/finceptterminal" <<WRAPPER
    #!${stdenv.shell}
    # The install-dir under \$out/ contains both immutable bits (uv,
    # python, venv-numpy{1,2}, sentinel) AND mutable bits the runtime
    # later wants to populate (workspace.db, logs/, cache/, models/,
    # workspaces/, crashdumps/, ...). The Nix store is read-only, so
    # we mirror the immutable entries into a per-user writable copy
    # and point FINCEPT_INSTALL_DIR at the writable side. The flox
    # env sets FINCEPT_DATA_DIR to \$FLOX_ENV_CACHE/finceptterminal in
    # its on-activate hook; we use it when present and otherwise fall
    # back to \$XDG_DATA_HOME (or \$HOME/.local/share).
    nix_install_dir="$install_dir"
    data_dir="\''${FINCEPT_DATA_DIR:-\''${XDG_DATA_HOME:-\$HOME/.local/share}/finceptterminal}"
    user_install_dir="\''${FINCEPT_INSTALL_DIR:-\$data_dir/install-dir}"
    mkdir -p "\$user_install_dir"
    for entry in .fincept-nix-managed uv python venv-numpy1 venv-numpy2; do
      target="\$nix_install_dir/\$entry"
      link="\$user_install_dir/\$entry"
      if [ -e "\$target" ] && [ ! -e "\$link" ]; then
        ln -s "\$target" "\$link"
      fi
    done
    export FINCEPT_INSTALL_DIR="\$user_install_dir"
    export QT_PLUGIN_PATH="$out/lib/qt-6/plugins\''${QT_PLUGIN_PATH:+:\$QT_PLUGIN_PATH}"
    export QT_QPA_PLATFORM_PLUGIN_PATH="$out/lib/qt-6/plugins/platforms\''${QT_QPA_PLATFORM_PLUGIN_PATH:+:\$QT_QPA_PLATFORM_PLUGIN_PATH}"
    export LD_LIBRARY_PATH="${
      lib.makeLibraryPath [
        portaudio
        expat
        openssl
      ]
    }\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
    exec "$out/bin/.finceptterminal-unwrapped" "\$@"
    WRAPPER
    chmod +x "$out/bin/finceptterminal"

    # Lock down the install-dir tree — read-only for everyone.
    # Symlinks are not mode-bearing so this only affects the
    # directory entries + plain files (sentinel + markers).
    chmod -R a-w,a+rX "$install_dir"

    runHook postInstall
  '';

  meta = {
    description = "Native Qt 6 / C++20 financial-analytics desktop terminal";
    homepage = "https://github.com/Fincept-Corporation/FinceptTerminal";
    license = lib.licenses.agpl3Only;
    mainProgram = "finceptterminal";
    # aarch64-linux is intentionally absent: the uv workspace excludes
    # it because pyqlib==0.9.7 has no aarch64-linux wheel and we
    # don't currently maintain an sdist-build path for it. See the
    # design doc risk note (.plans/2026-05-21-...-design.md §"Risks")
    # and the uv pyproject.toml [tool.uv].environments block.
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
