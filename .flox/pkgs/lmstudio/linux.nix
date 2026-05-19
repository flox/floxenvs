{
  appimageTools,
  fetchurl,
  lib,
  stdenv,
  graphicsmagick,
  makeWrapper,
  xorg-server,
  version,
  url,
  hash,
  meta,
}:
let
  pname = "lmstudio";

  src = fetchurl { inherit url hash; };

  appimageContents = appimageTools.extractType2 { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit
    meta
    pname
    version
    src
    ;

  nativeBuildInputs = [ graphicsmagick ];

  extraPkgs = pkgs: [ pkgs.ocl-icd ];

  # Make host NVIDIA driver libraries available inside the bwrap sandbox.
  # buildFHSEnv creates an isolated filesystem — host GPU libraries are not
  # available.  We can't bind-mount entire host lib dirs (e.g. /usr/lib/
  # x86_64-linux-gnu) because the host's glibc/libstdc++ would conflict with
  # the Nix-provided versions and cause segfaults.  Instead, extraPreBwrapCmds
  # creates a filtered directory with ONLY nvidia/cuda libraries (via hard
  # links) under ~/.cache/lmstudio-nvidia-drivers, which is visible in the
  # sandbox via the /home bind mount.  The profile then appends it to
  # LD_LIBRARY_PATH.
  extraPreBwrapCmds = ''
    __nvidia_cache="$HOME/.cache/lmstudio-nvidia-drivers"
    rm -rf "$__nvidia_cache" 2>/dev/null || true
    mkdir -p "$__nvidia_cache"
    for pattern in libnvidia libcuda libEGL_nvidia libGLX_nvidia libvdpau_nvidia libnvcuvid libcudadebugger; do
      for dir in /usr/lib/x86_64-linux-gnu /usr/lib/aarch64-linux-gnu /usr/lib64 /usr/lib /run/opengl-driver/lib; do
        for f in "$dir"/$pattern*.so*; do
          [ -f "$f" ] && ln -f "$f" "$__nvidia_cache/" 2>/dev/null || cp -f "$f" "$__nvidia_cache/" 2>/dev/null || true
        done
      done
    done
    # Also copy nvidia-smi if available
    for smi in /usr/bin/nvidia-smi; do
      [ -x "$smi" ] && cp -f "$smi" "$__nvidia_cache/" 2>/dev/null || true
    done
  '';

  profile = ''
    __nvidia_cache="$HOME/.cache/lmstudio-nvidia-drivers"
    if [ -d "$__nvidia_cache" ]; then
      export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$__nvidia_cache"
      export PATH="$PATH:$__nvidia_cache"
    fi
  '';

  # Expose NVIDIA GPU devices and sysfs info to the bwrap sandbox.
  # --dev-bind-try / --ro-bind-try are no-ops when paths don't exist,
  # so CPU-only systems are handled safely.
  extraBwrapArgs = [
    # GPU device nodes
    "--dev-bind-try"
    "/dev/nvidia0"
    "/dev/nvidia0"
    "--dev-bind-try"
    "/dev/nvidia1"
    "/dev/nvidia1"
    "--dev-bind-try"
    "/dev/nvidiactl"
    "/dev/nvidiactl"
    "--dev-bind-try"
    "/dev/nvidia-uvm"
    "/dev/nvidia-uvm"
    "--dev-bind-try"
    "/dev/nvidia-uvm-tools"
    "/dev/nvidia-uvm-tools"
    "--dev-bind-try"
    "/dev/nvidia-caps"
    "/dev/nvidia-caps"
    "--dev-bind-try"
    "/dev/nvidia-modeset"
    "/dev/nvidia-modeset"
    "--dev-bind-try"
    "/dev/dri"
    "/dev/dri"
    # GPU sysfs info (PCI device enumeration, temp sensors, etc.)
    "--ro-bind-try"
    "/sys/bus/pci"
    "/sys/bus/pci"
    "--ro-bind-try"
    "/sys/devices/pci0000:00"
    "/sys/devices/pci0000:00"
  ];

  extraInstallCommands = ''
    mkdir -p $out/share/applications

    # Setup icons
    src_icon="${appimageContents}/usr/share/icons/hicolor/0x0/apps/lm-studio.png"
    sizes=("16x16" "32x32" "48x48" "64x64" "128x128" "256x256")
    for size in "''${sizes[@]}"; do
      install -dm755 "$out/share/icons/hicolor/$size/apps"
      gm convert "$src_icon" -resize "$size" "$out/share/icons/hicolor/$size/apps/lm-studio.png"
    done

    install -m 444 -D ${appimageContents}/lm-studio.desktop -t $out/share/applications

    # Rename the main executable from lmstudio to lm-studio
    mv $out/bin/lmstudio $out/bin/lm-studio

    substituteInPlace $out/share/applications/lm-studio.desktop \
      --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=lm-studio'

    # lms cli tool — this is a Bun single-executable binary with an embedded
    # JS bundle. patchelf corrupts embedded data blobs by shifting ELF section
    # offsets, and invoking via ld-linux breaks /proc/self/exe resolution that
    # Bun needs to locate its bundle. We use LD_LIBRARY_PATH instead.
    install -m 755 ${appimageContents}/resources/app/.webpack/lms $out/bin/.lms-unwrapped

    # GPU detection + dynamic linker wrapper
    cat > $out/bin/lms << WRAPPER
    #!/usr/bin/env bash
    # LM Studio requires NVIDIA (CUDA) or a Vulkan-capable discrete GPU.
    # The lms binary segfaults at startup on systems without one.
    has_gpu=false
    if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
      has_gpu=true
    elif command -v vulkaninfo &>/dev/null && vulkaninfo --summary 2>/dev/null | grep -q 'deviceType.*DISCRETE'; then
      has_gpu=true
    fi

    if [ "\$has_gpu" = false ]; then
      echo "LM Studio requires a supported GPU (NVIDIA with CUDA, or discrete AMD/Intel with Vulkan)." >&2
      echo "No compatible GPU detected. The lms binary will segfault without one." >&2
      echo "" >&2
      echo "To bypass this check: LMS_SKIP_GPU_CHECK=1 lms [args...]" >&2
      [ "\''${LMS_SKIP_GPU_CHECK:-}" = "1" ] || exit 1
    fi

    export LD_LIBRARY_PATH="${lib.getLib stdenv.cc.cc}/lib:${lib.getLib stdenv.cc.cc}/lib64:$out/lib:${
      lib.makeLibraryPath [ (lib.getLib stdenv.cc.cc) ]
    }\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
    exec "$out/bin/.lms-unwrapped" "\$@"
    WRAPPER
    chmod +x $out/bin/lms

    # --- lms-service: headless LM Studio service launcher ---
    install -m 755 ${./lms-service.sh} $out/bin/lms-service
    substituteInPlace $out/bin/lms-service \
      --replace-fail '@lms@' "$out/bin/.lms-unwrapped" \
      --replace-fail '@lm_studio@' "$out/bin/lm-studio" \
      --replace-fail '@xvfb@' "${xorg-server}/bin/Xvfb" \
      --replace-fail '@lib_path@' "${lib.getLib stdenv.cc.cc}/lib:${lib.getLib stdenv.cc.cc}/lib64:$out/lib:${
        lib.makeLibraryPath [ (lib.getLib stdenv.cc.cc) ]
      }"

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
  '';
}
