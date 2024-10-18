set -euxo pipefail

curl localhost:8080 | grep "Hello World!"
