{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  versionCheckHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash npmDepsHash;
in
buildNpmPackage {
  npmDepsFetcherVersion = 2;
  pname = "cclint";
  inherit version;

  src = fetchFromGitHub {
    owner = "carlrannaberg";
    repo = "cclint";
    tag = "v${version}";
    hash = srcHash;
  };

  inherit npmDepsHash;
  makeCacheWritable = true;

  # husky `prepare` hook must not run in the sandbox.
  npmFlags = [ "--ignore-scripts" ];

  # TypeScript build emits dist/ that bin/cclint.js imports.
  npmBuildScript = "build";

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "Lint Claude Code agents, commands, settings.json, and CLAUDE.md";
    homepage = "https://github.com/carlrannaberg/cclint";
    changelog = "https://github.com/carlrannaberg/cclint/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    mainProgram = "cclint";
    platforms = lib.platforms.unix;
  };
}
