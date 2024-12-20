set -euxo pipefail

MAX_ATTEMPTS=10
while [ $MAX_ATTEMPTS -gt 0 ]; do
  set +e
  STATUS=$(curl -s http://localhost:$NGINX_PORT| grep '<title>Hello Flox!</title>')
  set -e
  if [ "$STATUS" == "    <title>Hello Flox!</title>" ]; then
    break
  fi
  echo -n ".."
  sleep 1
  MAX_ATTEMPTS=$((MAX_ATTEMPTS - 1))
done

if [ $MAX_ATTEMPTS -eq 0 ]; then
  echo ""
  echo "❌ Error: Nginx didn't come up in time."
  exit 1
fi

echo ""
echo "✅ Nginx serving correctly!"

echo ">>> flox services status"
flox services status

echo ">>> flox services logs nginx"
flox services logs nginx
