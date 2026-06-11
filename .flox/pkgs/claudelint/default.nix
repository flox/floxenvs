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
  pname = "claude-code-lint";
  inherit version;

  src = fetchFromGitHub {
    owner = "pdugan20";
    repo = "claudelint";
    tag = "v${version}";
    hash = srcHash;
  };

  inherit npmDepsHash;
  makeCacheWritable = true;

  # The `prepare` lifecycle hook runs `setup-hooks.sh` (git hooks); it
  # must not run in the sandbox.
  npmFlags = [ "--ignore-scripts" ];

  # TypeScript build emits dist/ that bin/claudelint requires. prebuild
  # (rule-types) and postbuild (presets) generate sources via ts-node.
  npmBuildScript = "build";

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description = "Linter for the whole Claude Code project: skills, agents, settings, hooks, MCP";
    homepage = "https://github.com/pdugan20/claudelint";
    changelog = "https://github.com/pdugan20/claudelint/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    mainProgram = "claudelint";
    platforms = lib.platforms.unix;
  };
}
