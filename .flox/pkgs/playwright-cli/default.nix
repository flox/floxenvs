{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash npmDepsHash;
in
buildNpmPackage (finalAttrs: {
  pname = "playwright-cli";
  inherit version;

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "playwright-cli";
    tag = "v${finalAttrs.version}";
    hash = srcHash;
  };

  inherit npmDepsHash nodejs;

  # The npm `prepare`/`install` scripts in the
  # playwright-core dep would download chromium /
  # firefox / webkit into the build sandbox. We
  # provide browsers via `playwright-driver` at the
  # env layer, so skip those downloads at build time.
  env = {
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS = "1";
  };

  # No build step — the CLI is a single Node script
  # that requires `playwright-core` at runtime.
  dontNpmBuild = true;

  meta = {
    description =
      "Microsoft Playwright CLI — record and "
      + "generate Playwright code, inspect "
      + "selectors, drive a browser from the shell.";
    homepage =
      "https://github.com/microsoft/playwright-cli";
    license = lib.licenses.asl20;
    sourceProvenance =
      with lib.sourceTypes; [ fromSource ];
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    mainProgram = "playwright-cli";
  };
})
