{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash vendorHash;
in
buildGoModule {
  pname = "skill-validator";
  inherit version;

  src = fetchFromGitHub {
    owner = "agent-ecosystem";
    repo = "skill-validator";
    tag = "v${version}";
    hash = srcHash;
  };

  inherit vendorHash;

  subPackages = [ "cmd/skill-validator" ];

  ldflags = [
    "-s"
    "-w"
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description =
      "Validate and score Claude Agent Skills (SKILL.md)";
    homepage =
      "https://github.com/agent-ecosystem/skill-validator";
    changelog =
      "https://github.com/agent-ecosystem/skill-validator/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "skill-validator";
    platforms = lib.platforms.unix;
  };
}
