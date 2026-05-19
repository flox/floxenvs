{
  stdenv,
  fetchurl,
  undmg,
  darwin,
  meta,
  version,
  url,
  hash,
}:
stdenv.mkDerivation {
  inherit meta version;
  pname = "lmstudio";

  src = fetchurl {
    inherit url hash;
  };

  nativeBuildInputs = [
    undmg
    darwin.sigtool
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications
    cp -r *.app $out/Applications

    # Bypass the /Applications path check in the main index.js
    local indexJs="$out/Applications/LM Studio.app/Contents/Resources/app/.webpack/main/index.js"
    substituteInPlace "$indexJs" --replace-quiet "'/Applications'" "'/'"

    # Re-sign the app bundle after patching
    /usr/bin/codesign --force --sign - "$out/Applications/LM Studio.app"

    # --- lm-studio wrapper (binary has a space in its path) ---
    mkdir -p $out/bin
    cat > $out/bin/lm-studio << LM_STUDIO
    #!/usr/bin/env bash
    exec "$out/Applications/LM Studio.app/Contents/MacOS/LM Studio" "\$@"
    LM_STUDIO
    chmod +x $out/bin/lm-studio

    # --- lms CLI (native Mach-O arm64, no patchelf needed) ---
    install -m 755 "$out/Applications/LM Studio.app/Contents/Resources/app/.webpack/lms" $out/bin/.lms-unwrapped

    cat > $out/bin/lms << LMS_WRAPPER
    #!/usr/bin/env bash
    # LM Studio requires a supported GPU (Metal on macOS).
    has_gpu=false
    if /usr/sbin/system_profiler SPDisplaysDataType 2>/dev/null | grep -qi 'metal'; then
      has_gpu=true
    fi

    if [ "\$has_gpu" = false ]; then
      echo "LM Studio requires a GPU with Metal support on macOS." >&2
      echo "No compatible GPU detected." >&2
      echo "" >&2
      echo "To bypass this check: LMS_SKIP_GPU_CHECK=1 lms [args...]" >&2
      [ "\''${LMS_SKIP_GPU_CHECK:-}" = "1" ] || exit 1
    fi

    exec "$out/bin/.lms-unwrapped" "\$@"
    LMS_WRAPPER
    chmod +x $out/bin/lms

    # --- lms-service: headless LM Studio service launcher (no Xvfb on macOS) ---
    install -m 755 ${./lms-service-darwin.sh} $out/bin/lms-service
    substituteInPlace $out/bin/lms-service \
      --replace-fail '@lms@' "$out/bin/.lms-unwrapped" \
      --replace-fail '@lm_studio@' "$out/bin/lm-studio"

    # --- lmstudio-health: health check ---
    cat > $out/bin/lmstudio-health << 'LMS_HEALTH'
    #!/usr/bin/env bash
    host="''${LMS_HOST:-127.0.0.1}"
    port="''${LMS_PORT:-1234}"
    url="http://$host:$port/v1/models"

    response=$(curl -sf "$url" 2>/dev/null) || {
      echo "UNHEALTHY: LM Studio not responding at $url" >&2
      exit 1
    }

    echo "HEALTHY: LM Studio responding at $url"
    if command -v jq &>/dev/null; then
      models=$(echo "$response" | jq -r '.data[].id' 2>/dev/null)
      if [ -n "$models" ]; then
        echo "Loaded models:"
        echo "$models" | sed 's/^/  - /'
      else
        echo "No models currently loaded."
      fi
    fi
    LMS_HEALTH
    chmod +x $out/bin/lmstudio-health

    # --- lms-launch: download, load, and launch agentic tools ---
    install -m 755 ${./lms-launch.sh} $out/bin/lms-launch

    # --- lmstudio-info: display configuration ---
    install -m 755 ${./lmstudio-info.sh} $out/bin/lmstudio-info

    runHook postInstall
  '';

  dontFixup = true;

  # undmg doesn't support APFS; use hdiutil directly
  unpackCmd = ''
    mnt=$(TMPDIR=/tmp mktemp -d -t nix-XXXXXXXXXX)
    function finish {
      /usr/bin/hdiutil detach $mnt -force
      rm -rf $mnt
    }
    trap finish EXIT
    /usr/bin/hdiutil attach -nobrowse -mountpoint $mnt $curSrc
    cp -a $mnt/LM\ Studio.app $PWD/
  '';
}
