#!/usr/bin/env bash

set -eo pipefail

echo '
package main

import "fmt"

func main() {
    fmt.Println("Hello world!")
}
' > main.go

go build -o main.wasm main.go

ACTUAL="$(wasmtime main.wasm)"
EXPECTED="Hello world!"

if [ "$ACTUAL" != "$EXPECTED" ]; then
    echo "Error: 'wasmtime main.wasm' did not return '$EXPECTED'."
    exit 1
fi

rm main.go main.wasm
