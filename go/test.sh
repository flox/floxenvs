#!/usr/bin/env bash

set -eo pipefail

if ! command -v go >/dev/null 2>&1; then
  echo "Error: 'go' command not found."
  exit 1
fi

echo ">>> go version"
go version

echo ">>> cgo build"
cgo_dir="$(mktemp -d)"
trap 'rm -rf "$cgo_dir"' EXIT
cat > "$cgo_dir/main.go" <<'GO'
package main

/*
#include <stdlib.h>
*/
import "C"

import "fmt"

func main() {
	fmt.Println(C.int(42))
}
GO
(
  cd "$cgo_dir"
  go mod init cgotest >/dev/null
  CGO_ENABLED=1 go build -o cgotest .
  ./cgotest
)

echo ">>> Go environment is working"
