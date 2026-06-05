{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  fetchurl,
  chromium,
  makeBinaryWrapper,
  nodejs-slim,
  pnpmConfigHook,
  pnpm_11,
  rustPlatform,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    srcHash
    cargoHash
    pnpmDepsHash
    ;

  # Vendored Geist variable font (OFL-1.1) pinned to a specific upstream
  # commit so the dashboard's next/font build is fully offline.
  geistVariable = fetchurl {
    url =
      "https://raw.githubusercontent.com/vercel/geist-font/"
      + "77f0563c03009d6c15c6342183fa53b352255b22/"
      + "packages/next/dist/fonts/geist-sans/Geist-Variable.woff2";
    hash = "sha256-L/6+mT6WkGmpeJ0VFkt3FdQkkbWDVRbF47k11fgbBfE=";
  };

  src = fetchFromGitHub {
    owner = "vercel-labs";
    repo = "agent-browser";
    tag = "v${version}";
    hash = srcHash;
  };

  # The dashboard is a Next.js app built with pnpm; bake it into a fixed
  # output that the Rust CLI's build.rs and runtime asset embedder can
  # reference via the patched paths below.
  dashboard = stdenv.mkDerivation {
    pname = "agent-browser-dashboard";
    inherit version src;

    nativeBuildInputs = [
      nodejs-slim
      pnpm_11
      pnpmConfigHook
    ];

    pnpmDeps = fetchPnpmDeps {
      pname = "agent-browser-dashboard";
      inherit version src;
      pnpm = pnpm_11;
      hash = pnpmDepsHash;
      fetcherVersion = 3;
    };

    # next/font/google fetches Geist from fonts.googleapis.com at build
    # time, which the Nix sandbox blocks. Swap it for next/font/local
    # pointing at the vendored woff2.
    postPatch = ''
      install -Dm644 ${geistVariable} \
        packages/dashboard/src/app/Geist-Variable.woff2
      substituteInPlace packages/dashboard/src/app/layout.tsx \
        --replace-fail 'import { Geist } from "next/font/google"' \
                        'import Geist from "next/font/local"' \
        --replace-fail 'Geist({ subsets: ["latin"], variable: "--font-sans" })' \
                        'Geist({ src: "./Geist-Variable.woff2", variable: "--font-sans", display: "swap" })'
    '';

    buildPhase = ''
      runHook preBuild
      cd packages/dashboard
      pnpm build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r out/. $out/
      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage {
  pname = "agent-browser";
  inherit version src;

  sourceRoot = "source/cli";

  inherit cargoHash;

  nativeBuildInputs = lib.optional stdenv.hostPlatform.isLinux makeBinaryWrapper;
  buildInputs = lib.optional stdenv.hostPlatform.isLinux chromium;

  # Upstream pins fat LTO with codegen-units=1 while pulling in the full
  # `image` crate (avif/webp/tiff/jpeg/png/gif). The monolithic LTO link
  # OOMs rustc on the aarch64-linux builder; thin LTO keeps most of the
  # optimisation at a fraction of the peak memory.
  env.CARGO_PROFILE_RELEASE_LTO = "thin";

  # cargo-auditable panics on aarch64-darwin with this crate's dep tree.
  auditable = !stdenv.hostPlatform.isDarwin;

  # Auth/credential tests want a keyring not available in the sandbox.
  doCheck = false;

  postPatch = ''
    # Skill discovery walks up from the executable looking for a directory
    # that contains skills/. Point it at $out/share/agent-browser so both
    # skills/ and skill-data/ are found without polluting $out.
    substituteInPlace src/skills.rs \
      --replace-fail \
        'fn find_package_root() -> Option<PathBuf> {' \
        'fn find_package_root() -> Option<PathBuf> {
    let nix_root = PathBuf::from("${placeholder "out"}/share/agent-browser");
    if nix_root.join("skills").is_dir() {
        return Some(nix_root);
    }'

    substituteInPlace build.rs \
      --replace-fail 'Path::new("../packages/dashboard/out")' \
                      'Path::new("${dashboard}")'
    substituteInPlace src/native/stream/http.rs \
      --replace-fail '#[folder = "../packages/dashboard/out/"]' \
                      '#[folder = "${dashboard}/"]'
  '';

  postInstall = ''
    mkdir -p $out/share/agent-browser
    cp -r ../skills ../skill-data $out/share/agent-browser/
  ''
  + lib.optionalString stdenv.hostPlatform.isLinux ''
    wrapProgram $out/bin/agent-browser \
      --set AGENT_BROWSER_EXECUTABLE_PATH ${chromium}/bin/chromium
  '';

  meta = {
    description = "Headless browser automation CLI for AI agents";
    homepage = "https://github.com/vercel-labs/agent-browser";
    changelog = "https://github.com/vercel-labs/agent-browser/releases/tag/v${version}";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "agent-browser";
  };
}
