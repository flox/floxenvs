{
  lib,
  buildPythonPackage,
  fetchPypi,
  hatchling,
  uv-dynamic-versioning,
  pydantic,
  typing-extensions,
}:

buildPythonPackage rec {
  pname = "mcp-types";
  version = "2.3.0";
  pyproject = true;

  src = fetchPypi {
    pname = "mcp_types";
    inherit version;
    hash = "sha256-0eRlSe2zXuGalJQPzubRrd1+WJq36pLdqD9dhHgfw2I=";
  };

  build-system = [
    hatchling
    uv-dynamic-versioning
  ];

  # uv-dynamic-versioning derives the version from VCS metadata, which an
  # sdist does not carry. Its documented escape hatch short-circuits the
  # lookup with a literal version.
  env.UV_DYNAMIC_VERSIONING_BYPASS = version;

  dependencies = [
    pydantic
    typing-extensions
  ];

  pythonImportsCheck = [ "mcp_types" ];

  meta = {
    description = "Type definitions for the Model Context Protocol";
    homepage = "https://github.com/modelcontextprotocol/python-sdk";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
  };
}
