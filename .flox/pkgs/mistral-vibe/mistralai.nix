{
  lib,
  python3,
  fetchPypi,
}:

python3.pkgs.buildPythonPackage rec {
  pname = "mistralai";
  version = "2.4.4";
  pyproject = true;

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-zYonojDlRYtiI3psT3tS9b6GkJ+8GGlDYM6yHayTLto=";
  };

  build-system = with python3.pkgs; [ hatchling ];

  dependencies = with python3.pkgs; [
    eval-type-backport
    httpx
    jsonpath-python
    opentelemetry-api
    opentelemetry-semantic-conventions
    pydantic
    python-dateutil
    typing-inspection
  ];

  # mistralai pins opentelemetry-semantic-conventions<0.61 but the
  # mistral-vibe override supplies 0.61b0; the upper bound is
  # precautionary, not an actual API break.
  pythonRelaxDeps = [
    "opentelemetry-semantic-conventions"
  ];

  pythonImportsCheck = [ "mistralai" ];

  meta = with lib; {
    description = "Python Client SDK for the Mistral AI API";
    homepage = "https://github.com/mistralai/client-python";
    changelog = "https://github.com/mistralai/client-python/releases/tag/v${version}";
    license = licenses.asl20;
    sourceProvenance = with sourceTypes; [ fromSource ];
    platforms = platforms.all;
  };
}
