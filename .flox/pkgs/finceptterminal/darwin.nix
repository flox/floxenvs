{
  lib,
  stdenv,
  callPackage,
  qt6,
  darwin,
  openssl,
  expat,
  libiconv,
  libiconvReal,
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

    # Mirror scripts/ + resources/ + translations/ next to the binary
    # inside Contents/MacOS/. Qt's QCoreApplication::applicationDirPath
    # returns Contents/MacOS on macOS, and several upstream paths
    # (PythonRunner, ScriptCatalog) resolve scripts relative to it.
    # Without these, the app crashes at first launch trying to import
    # scripts/agents/finagent_core/main.py.
    macos_dir="$out/Applications/FinceptTerminal.app/Contents/MacOS"
    chmod -R u+w "$macos_dir"
    if [ -d "$build_dir/scripts" ]; then
      cp -R "$build_dir/scripts" "$macos_dir/"
    elif [ -d "$src_root/scripts" ]; then
      cp -R "$src_root/scripts" "$macos_dir/"
    fi
    cp -R "$src_root/resources"    "$macos_dir/" 2>/dev/null || true
    cp -R "$src_root/translations" "$macos_dir/" 2>/dev/null || true

    # macdeployqt vendors the Qt frameworks into the .app so it works
    # outside the build sandbox.
    "${qt6.qtbase}/bin/macdeployqt" \
      "$out/Applications/FinceptTerminal.app" \
      -verbose=1 || true

    # Dual libiconv fix: the Nix dep graph mixes two libiconv ABIs.
    # Apple's libiconv exports `_iconv*` (libcups, libglib, libintl,
    # libodbc link against this — compat version 7.0.0) and GNU
    # libiconv exports `_libiconv*` (libgnutls, libidn2, libunistring,
    # … — compat version 10.0.0). macdeployqt collapses both into a
    # single `libiconv.2.dylib`, so half the consumers crash at first
    # launch with `Symbol not found: _iconv` or `_libiconv`.
    #
    # Workaround: ship both libiconvs side by side (the GNU build at
    # the canonical name, Apple's at `libiconv-apple.2.dylib`) and
    # rewrite the load command on every Apple-ABI consumer to point at
    # the alternate file. Distinguishing the two is straightforward —
    # the compat-version field in the install_name differs (7 vs 10).
    frameworks="$out/Applications/FinceptTerminal.app/Contents/Frameworks"
    if [ -e "$frameworks/libiconv.2.dylib" ]; then
      chmod -R u+w "$frameworks"

      # Drop in the GNU build at the canonical path.
      cp -f ${libiconvReal}/lib/libiconv.2.dylib \
            "$frameworks/libiconv.2.dylib"
      chmod u+w "$frameworks/libiconv.2.dylib"
      install_name_tool -id @executable_path/../Frameworks/libiconv.2.dylib \
        "$frameworks/libiconv.2.dylib"

      # Drop in Apple's build under an alternate filename.
      cp -f ${libiconv}/lib/libiconv.2.dylib \
            "$frameworks/libiconv-apple.2.dylib"
      chmod u+w "$frameworks/libiconv-apple.2.dylib"
      install_name_tool -id @executable_path/../Frameworks/libiconv-apple.2.dylib \
        "$frameworks/libiconv-apple.2.dylib"

      # Rewrite the load command on Apple-ABI consumers. The compat
      # version is encoded in `otool -L` as `(compatibility version
      # 7.0.0, current version 7.0.0)` — match on that to identify the
      # consumers without hardcoding a list.
      for dylib in "$frameworks"/*.dylib; do
        [ "$dylib" = "$frameworks/libiconv.2.dylib" ] && continue
        [ "$dylib" = "$frameworks/libiconv-apple.2.dylib" ] && continue
        if otool -L "$dylib" 2>/dev/null | \
            grep -q 'Frameworks/libiconv.2.dylib (compatibility version 7'; then
          chmod u+w "$dylib"
          install_name_tool -change \
            @executable_path/../Frameworks/libiconv.2.dylib \
            @executable_path/../Frameworks/libiconv-apple.2.dylib \
            "$dylib"
        fi
      done
    fi

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
    # See linux.nix for the rationale — install-dir holds both
    # immutable bits (uv, python, venv-numpy{1,2}, sentinel) and
    # mutable bits (workspace.db, logs/, cache/, ...). The Nix store
    # is read-only, so mirror the immutable entries into a per-user
    # writable copy and point FINCEPT_INSTALL_DIR there.
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
