{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  rustPlatform,
  pkg-config,
  libiconv,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData)
    version
    srcHash
    cargoHash
    litellmOwner
    litellmRepo
    litellmRev
    litellmPricingHash
    ;
  litellmPricing = fetchurl {
    url = "https://raw.githubusercontent.com/${litellmOwner}/${litellmRepo}/${litellmRev}/model_prices_and_context_window.json";
    hash = litellmPricingHash;
  };
in
rustPlatform.buildRustPackage {
  pname = "ccusage";
  inherit version;

  src = fetchFromGitHub {
    owner = "ryoppippi";
    repo = "ccusage";
    tag = "v${version}";
    hash = srcHash;
  };

  sourceRoot = "source/rust";

  inherit cargoHash;

  cargoBuildFlags = [
    "-p"
    "ccusage"
    "--bin"
    "ccusage"
  ];

  doCheck = false;

  nativeBuildInputs = [ pkg-config ];

  buildInputs = lib.optionals stdenv.hostPlatform.isDarwin [
    libiconv
  ];

  # Sandboxed builds on Linux have no network; point the build script at a
  # pre-fetched LiteLLM pricing snapshot instead of letting it call out.
  env.CCUSAGE_PRICING_JSON_PATH = litellmPricing;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  versionCheckKeepEnvironment = [ "HOME" ];

  meta = {
    description = "Analyze coding agent CLI token usage and costs from local data";
    homepage = "https://github.com/ryoppippi/ccusage";
    changelog = "https://github.com/ryoppippi/ccusage/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.all;
    mainProgram = "ccusage";
  };
}
