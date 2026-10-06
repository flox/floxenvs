{
  lib,
  buildPythonPackage,
  fetchPypi,
  hatchling,
  uv-dynamic-versioning,
  anyio,
  httpx2,
  jsonschema,
  mcp-types,
  opentelemetry-api,
  pydantic,
  pyjwt,
  python-multipart,
  sse-starlette,
  starlette,
  typing-extensions,
  typing-inspection,
  uvicorn,
}:

buildPythonPackage rec {
  pname = "mcp";
  version = "2.3.0";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-ixR6UEQc8FnciMaE4K7tNofwqg85xs3nuQMw7/0rNNg=";
  };

  build-system = [
    hatchling
    uv-dynamic-versioning
  ];

  # See mcp-types.nix: the sdist has no VCS metadata for
  # uv-dynamic-versioning to read.
  env.UV_DYNAMIC_VERSIONING_BYPASS = version;

  dependencies = [
    anyio
    httpx2
    jsonschema
    mcp-types
    opentelemetry-api
    pydantic
    pyjwt
    python-multipart
    sse-starlette
    starlette
    typing-extensions
    typing-inspection
    uvicorn
  ];

  # mcp asks for httpx2>=2.10.0 while nixpkgs ships 2.9.1. Every httpx2
  # name mcp actually uses — AsyncClient, Auth, Request, Response,
  # Timeout, SSEError, StreamError, TransportError and HTTPStatusError —
  # is already exported by 2.9.1, so the floor is a version bump rather
  # than a new API.
  pythonRelaxDeps = [ "httpx2" ];

  pythonImportsCheck = [
    "mcp"
    "mcp.server"
  ];

  meta = {
    description = "Model Context Protocol SDK";
    homepage = "https://github.com/modelcontextprotocol/python-sdk";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
  };
}
