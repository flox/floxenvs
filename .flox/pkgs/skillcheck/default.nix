{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version rev srcHash npmDepsHash;
in
buildNpmPackage {
  npmDepsFetcherVersion = 2;
  pname = "skillcheck";
  inherit version;

  # Upstream publishes no git tags or releases, so pin to a commit on
  # the default branch. `rev` is tracked in hashes.json.
  src = fetchFromGitHub {
    owner = "agentigy";
    repo = "skillcheck";
    inherit rev;
    hash = srcHash;
  };

  inherit npmDepsHash;
  makeCacheWritable = true;

  npmFlags = [ "--ignore-scripts" ];

  # Zero runtime deps; tsc emits dist/cli.js (the bin entrypoint).
  npmBuildScript = "build";

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "SAST scanner for SKILL.md bodies — secrets, injection, priv-esc (SARIF)";
    homepage = "https://github.com/agentigy/skillcheck";
    changelog = "https://github.com/agentigy/skillcheck/commits/main";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    mainProgram = "skillcheck";
    platforms = lib.platforms.unix;
  };
}
