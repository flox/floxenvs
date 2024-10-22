set -euxo pipefail

if curl -s http://localhost:$NGINX_PORT| grep -q "<title>Hello Flox!</title>"; then
    echo ">>> Nginx serving correctly!"
else
    echo "ERROR: Nginx not working correctly!"
    exit 1
fi
