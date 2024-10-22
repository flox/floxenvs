set -euxo pipefail

if curl -s http://localhost:8080 | grep -q "<title>Hello Flox!</title>"; then
    echo ">>> Nginx serving correctly!"
else
    echo "ERROR: Nginx not working correctly!"
    exit 1
fi
