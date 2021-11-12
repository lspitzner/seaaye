#!/bin/bash

OUTDIR="nix/ci-out"
SUMMARY="$OUTDIR/0-summary"

set -e

function cabal-check {
  set +e
  local EXITCODE=0
  nix-build --no-out-link nix/seaaye-cache/cabal-check.drv \
    2> >(tee "$OUTDIR/cabal-check.txt" >&2) 1>/dev/null \
    || EXITCODE=$?
  (($EXITCODE == 0)) || { echo "! cabal-check: failed" >> "$SUMMARY"; return 1; }
  echo "· cabal-check: success" | tee -a "$SUMMARY"
}

function run-test {
  local DRVPATH=$1
  local TESTNAME=$2
  nix-build -Q $DRVPATH -o "$OUTDIR/$TESTNAME-test-result" >/dev/null
  (($? == 0)) || { echo "! $TESTNAME: run test failed" >> "$SUMMARY"; return 1; }
  echo "· $TESTNAME: $(tail -n1 "$OUTDIR/$TESTNAME-test-result/test-stdout")" | tee -a "$SUMMARY"
}

mkdir -p "$OUTDIR"
echo "# test summary" > "$SUMMARY"

find "$OUTDIR" -name "stackage*" -delete
find "$OUTDIR" -name "hackage*" -delete
rm -f "$OUTDIR/cabal-check.txt"

echo "running cabal-check.."
cabal-check

for F in $(find nix/seaaye-cache -name "check-*" | sort)
  do
    NAME=$(echo "$F" | sed -En 's|nix/seaaye-cache/check-.......-(.*)-[^-]*.drv|\1|p')
    echo "running $NAME .."
    run-test $F $NAME
done

echo ""
cat "$SUMMARY"
