{
  lib,
  stdenv,
  callPackage,
  qt6,
  darwin,
  openssl,
  expat,
  uv,
  pythonEnv,
}:

let
  common = callPackage ./common.nix { };
in
common.overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [
    darwin.sigtool
  ];

  cmakeFlags = old.cmakeFlags ++ [
    "-DCMAKE_OSX_DEPLOYMENT_TARGET=13.0"
  ];

  # macOS build produces FinceptTerminal.app inside the cmake build
  # dir. We copy it to $out/Applications, vendor Qt frameworks via
  # macdeployqt, ad-hoc re-sign, and emit a bin/finceptterminal shim
  # that execs into the bundle.
  installPhase = ''
    runHook preInstall

    src_root="$(realpath ..)"
    build_dir="$(pwd)"

    mkdir -p "$out/Applications"
    cp -R "$build_dir/FinceptTerminal.app" "$out/Applications/"

    # macdeployqt vendors the Qt frameworks into the .app so it works
    # outside the build sandbox.
    "${qt6.qtbase}/bin/macdeployqt" \
      "$out/Applications/FinceptTerminal.app" \
      -verbose=1 || true

    # Re-sign ad-hoc after bundle modification.
    /usr/bin/codesign --force --deep --sign - \
      "$out/Applications/FinceptTerminal.app"

    # Resource trees (scripts, resources). The .app's Contents/Resources
    # already has what upstream's install rules placed there during
    # the build; we mirror the Linux layout for consistency.
    mkdir -p "$out/share/finceptterminal"
    if [ -d "$build_dir/scripts" ]; then
      cp -R "$build_dir/scripts" "$out/share/finceptterminal/"
    elif [ -d "$src_root/scripts" ]; then
      cp -R "$src_root/scripts" "$out/share/finceptterminal/"
    fi
    cp -R "$src_root/resources" "$out/share/finceptterminal/" 2>/dev/null || true

    # ── Install-dir layout (mirror of linux.nix) ────────────────
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
    ln -s ${pythonEnv}/bin/python3.11 \
          "$install_dir/venv-numpy2/bin/python3"
    ln -s ${pythonEnv}/lib/python3.11/site-packages \
          "$install_dir/venv-numpy2/lib/python3.11/site-packages"
    ln -s ${pythonEnv}/bin/python3.11 \
          "$install_dir/venv-numpy1/bin/python3"
    ln -s ${pythonEnv}/lib/python3.11/site-packages \
          "$install_dir/venv-numpy1/lib/python3.11/site-packages"

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

    # bin shim — the .app binary has a space in its directory path,
    # so we wrap it for $PATH convenience.
    mkdir -p "$out/bin"
    cat > "$out/bin/finceptterminal" <<WRAPPER
    #!${stdenv.shell}
    export FINCEPT_INSTALL_DIR="\''${FINCEPT_INSTALL_DIR:-$install_dir}"
    export DYLD_LIBRARY_PATH="${
      lib.makeLibraryPath [
        openssl
        expat
      ]
    }\''${DYLD_LIBRARY_PATH:+:\$DYLD_LIBRARY_PATH}"
    exec "$out/Applications/FinceptTerminal.app/Contents/MacOS/FinceptTerminal" "\$@"
    WRAPPER
    chmod +x "$out/bin/finceptterminal"

    chmod -R a-w,a+rX "$install_dir"

    runHook postInstall
  '';

  # macdeployqt + ad-hoc codesign give us a bundle that can run from
  # the Nix store. Don't let stdenv's fixup pass try to relocate
  # anything — it'd break the codesign.
  dontFixup = true;

  meta = {
    description = "Native Qt 6 / C++20 financial-analytics desktop terminal";
    homepage = "https://github.com/Fincept-Corporation/FinceptTerminal";
    license = lib.licenses.agpl3Only;
    mainProgram = "finceptterminal";
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
