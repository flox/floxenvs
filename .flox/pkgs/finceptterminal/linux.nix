{
  lib,
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
