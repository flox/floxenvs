{
  lib,
  python3,
  fetchFromGitHub,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version srcHash;

  # spec-kit 1.1.1 requires `mcp>=2.2.0,<3.0.0` and imports MCPServer,
  # which only exists from 2.x:
  #   - mcp<3.0.0,>=2.2.0 not satisfied by version 1.29.0
  # nixpkgs ships 1.29.0, and relaxing the bound is not an option — the
  # `from mcp.server import MCPServer` in specify_cli/mcp_server/server.py
  # would fail at import time instead of at build time. Override mcp for
  # this package only, so every other consumer of python3Packages.mcp
  # keeps the 1.x it was built against. mcp 2.x also split its models out
  # into a separate mcp-types distribution, which nixpkgs does not carry
  # yet.
  python = python3.override {
    self = python;
    packageOverrides = pyfinal: _pyprev: {
      mcp-types = pyfinal.callPackage ./mcp-types.nix { };
      mcp = pyfinal.callPackage ./mcp.nix { };
    };
  };
in
python.pkgs.buildPythonApplication {
  pname = "spec-kit";
  inherit version;
  pyproject = true;

  src = fetchFromGitHub {
    owner = "github";
    repo = "spec-kit";
    tag = "v${version}";
    hash = srcHash;
  };

  build-system = with python.pkgs; [ hatchling ];

  dependencies = with python.pkgs; [
    typer
    rich
    httpx
    mcp
    pydantic
    socksio
    platformdirs
    readchar
    truststore
    pyyaml
    packaging
    pathspec
    json5
  ];

  pythonImportsCheck = [ "specify_cli" ];

  meta = {
    description = "GitHub Spec Kit's specify CLI - bootstrap spec-driven dev projects";
    homepage = "https://github.com/github/spec-kit";
    changelog = "https://github.com/github/spec-kit/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-linux"
    ];
    mainProgram = "specify";
  };
}
