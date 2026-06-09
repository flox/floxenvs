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

# ensemble3 w1 s1 w2 s2 w3 s3 -> round(w1*s1+w2*s2+w3*s3), weights in %
[ "$(ensemble3 40 82 30 90 30 60)" = "78" ] || { echo "FAIL ens skill"; exit 1; }
[ "$(ensemble3 50 95 30 65 20 100)" = "87" ] || { echo "FAIL ens agent"; exit 1; }

# fuse q r s i -> round(.35q+.35r+.20s+.10i)
[ "$(fuse 78 85 80 70)" = "80" ] || { echo "FAIL fuse"; exit 1; }

# apply_cap <score> <highest-severity none|LOW|MEDIUM|HIGH|CRITICAL>
[ "$(apply_cap 80 HIGH)" = "75" ]     || { echo "FAIL cap high"; exit 1; }
[ "$(apply_cap 80 CRITICAL)" = "50" ] || { echo "FAIL cap crit"; exit 1; }
[ "$(apply_cap 70 none)" = "70" ]     || { echo "FAIL cap none"; exit 1; }

# pill <score> -> stable|warn|risk
[ "$(pill 80)" = "stable" ] || { echo "FAIL pill stable"; exit 1; }
[ "$(pill 75)" = "warn" ]   || { echo "FAIL pill warn"; exit 1; }
[ "$(pill 59)" = "risk" ]   || { echo "FAIL pill risk"; exit 1; }
echo "PASS score.fusion"
