#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DIR/lib/score.sh"

# normalize_errwarn <errors> <warnings> -> clamp(100-25*err-5*warn,0,100)
[ "$(normalize_errwarn 0 0)" = "100" ] || { echo "FAIL clean"; exit 1; }
[ "$(normalize_errwarn 1 3)" = "60" ]  || { echo "FAIL 1e3w"; exit 1; }
[ "$(normalize_errwarn 5 0)" = "0" ]   || { echo "FAIL floor"; exit 1; }
[ "$(normalize_errwarn 0 2)" = "90" ]  || { echo "FAIL 2w"; exit 1; }
echo "PASS score.normalize_errwarn"
