{
  lib,
  rustPlatform,
  fetchFromGitHub,
  versionCheckHook,
}:

let
  versionData =
    builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash cargoHash;
in
rustPlatform.buildRustPackage {
  pname = "agnix";
  inherit version;

  src = fetchFromGitHub {
    owner = "agent-sh";
    repo = "agnix";
    tag = "v${version}";
    inherit hash;
  };

  inherit cargoHash;

  # Workspace also contains a wasm crate (agnix-wasm) that targets
  # wasm32 and won't build for the host. Build only the CLI crate,
  # which produces the `agnix` binary.
  cargoBuildFlags = [
    "--package"
    "agnix-cli"
  ];

  doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgramArg = "--version";

  meta = {
    description =
      "Linter + LSP for Claude Code skills, agents, CLAUDE.md, MCP, hooks";
    homepage = "https://github.com/agent-sh/agnix";
    changelog =
      "https://github.com/agent-sh/agnix/releases/tag/v${version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "agnix";
    platforms = lib.platforms.unix;
  };
}
