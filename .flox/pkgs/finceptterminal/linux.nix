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

  # The build emits FinceptTerminal directly under build/<preset>/.
  # We bypass CPack/IFW (that builds the upstream installer, not
  # what we want here) and install the binary + Qt plugins +
  # resources manually.
  #
  # Note: this installPhase is intentionally minimal. Phase 7 (Task
  # 7.2) extends it with the pre-built install-dir layout; Phase 8
  # (Task 8.1) adds the bin/finceptterminal wrapper. For now we
  # produce a working unwrapped binary and the resource trees.
  installPhase = ''
    runHook preInstall

    install -Dm755 build/*/FinceptTerminal "$out/bin/.finceptterminal-unwrapped"

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
    # These trees are what the upstream PythonRunner / ScriptCatalog
    # scan at runtime to discover available analytics modules.
    mkdir -p "$out/share/finceptterminal"
    cp -R scripts        "$out/share/finceptterminal/" 2>/dev/null || true
    cp -R resources      "$out/share/finceptterminal/" 2>/dev/null || true
    cp -R translations   "$out/share/finceptterminal/" 2>/dev/null || true

    # Desktop entry + icon for end users who want to wire it into
    # a window-manager launcher.
    install -Dm644 packaging/linux/fincept-terminal.desktop \
      "$out/share/applications/fincept-terminal.desktop" 2>/dev/null || true

    runHook postInstall
  '';

  meta = {
    description = "Native Qt 6 / C++20 financial-analytics desktop terminal";
    homepage = "https://github.com/Fincept-Corporation/FinceptTerminal";
    license = lib.licenses.agpl3Only;
    mainProgram = "finceptterminal";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
