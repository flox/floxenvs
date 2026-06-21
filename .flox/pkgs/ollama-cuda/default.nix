{
  lib,
  callPackage,
  buildEnv,
  cudaPackages,
  addDriverRunpath,
  autoAddDriverRunpath,
  makeBinaryWrapper,
}:

# ollama-cuda: the local ollama package with NVIDIA CUDA
# acceleration enabled. Version, source, and vendorHash are
# inherited from ../ollama via callPackage so the two stay in
# lockstep — bumping ollama bumps ollama-cuda automatically.

let
  ollama = callPackage ../ollama { };

  # Default CUDA target architectures. Covers from Maxwell
  # (GTX 9xx) through Hopper (H100). Add newer arches here
  # when cudaPackages in nixpkgs starts supporting them.
  cudaArches = [
    "50" # Maxwell  - GTX 9xx
    "60" # Pascal   - P100
    "61" # Pascal   - GTX 10xx, P40
    "70" # Volta    - V100
    "75" # Turing   - RTX 20xx, T4
    "80" # Ampere   - A100
    "86" # Ampere   - RTX 30xx
    "89" # Ada      - RTX 40xx
    "90" # Hopper   - H100
  ];
  cudaArchitectures = lib.concatStringsSep ";" cudaArches;

  cudaLibs = [
    cudaPackages.cuda_cudart
    cudaPackages.libcublas
    cudaPackages.cuda_cccl
  ];

  # ollama's CMakePresets.json hardcodes the CUDA major
  # version in its preset names, so we expose a merged
  # toolkit at $CUDA_PATH that contains nvcc plus the
  # libraries cmake needs to find.
  cudaMajorVersion =
    lib.versions.major cudaPackages.cuda_cudart.version;

  cudaToolkit = buildEnv {
    name = "cuda-merged-${cudaMajorVersion}";
    paths =
      map lib.getLib cudaLibs
      ++ [
        (lib.getOutput "static" cudaPackages.cuda_cudart)
        (lib.getBin (
          cudaPackages.cuda_nvcc.__spliced.buildHost
            or cudaPackages.cuda_nvcc
        ))
      ];
    ignoreCollisions = true;
  };

  cudaPath =
    lib.removeSuffix "-${cudaMajorVersion}" cudaToolkit;

  # ollama embeds llama.cpp binaries that run the actual
  # inference; their DT_RUNPATH is not patched, so we
  # leak the GPU runtime in via LD_LIBRARY_PATH at the
  # wrapper level. Same approach as nixpkgs upstream.
  wrapperArgs = builtins.concatStringsSep " " [
    "--suffix LD_LIBRARY_PATH : '${addDriverRunpath.driverLink}/lib'"
    "--suffix LD_LIBRARY_PATH : '${lib.makeLibraryPath (map lib.getLib cudaLibs)}'"
  ];
in
ollama.overrideAttrs (prevAttrs: {
  pname = "ollama-cuda";

  env = (prevAttrs.env or { }) // {
    CUDA_PATH = cudaPath;
  };

  nativeBuildInputs =
    (prevAttrs.nativeBuildInputs or [ ])
    ++ [
      cudaPackages.cuda_nvcc
      makeBinaryWrapper
      autoAddDriverRunpath
    ];

  buildInputs = (prevAttrs.buildInputs or [ ]) ++ cudaLibs;

  # Reuse ollama's own preBuild rather than replacing it: the base prefetches
  # llama.cpp and hands it to CMake via -DFETCHCONTENT_SOURCE_DIR_LLAMA_CPP.
  # Without that, CMake git-clones llama.cpp at build time and the Nix sandbox
  # blocks it ("Failed to clone repository"). We only need to add the CUDA
  # target architectures to the same configure step, so inject the flag right
  # after `cmake -B build` and keep everything else (llama.cpp source, compat
  # patches, MLX-disable, rpath flags) intact.
  preBuild = builtins.replaceStrings
    [ "cmake -B build \\\n" ]
    [ "cmake -B build \\\n      -DCMAKE_CUDA_ARCHITECTURES='${cudaArchitectures}' \\\n" ]
    prevAttrs.preBuild;

  postFixup = ''
    wrapProgram "$out/bin/ollama" ${wrapperArgs}
  '';

  meta = prevAttrs.meta // {
    description =
      prevAttrs.meta.description
      + ", using CUDA for NVIDIA GPU acceleration";
    platforms = [ "x86_64-linux" ];
  };
})
