#!/bin/bash

OUTDIR="nix/ci-out"
SUMMARY="$OUTDIR/0-summary"
FAILURE=0

set -e

function cabal-check {
  set +e
  local EXITCODE=0
  nix-build --no-out-link nix/seaaye-cache/cabal-check.drv \
    2> >(tee "$OUTDIR/cabal-check.txt" >&2) 1>/dev/null \
    || EXITCODE=$?
  ((EXITCODE == 0)) || { echo "! cabal-check: failed" >> "$SUMMARY"; return 1; }
  echo "· cabal-check: success" | tee -a "$SUMMARY"
}

function run-test {
  local DRVPATH=$1
  local TESTNAME=$2
  if ! nix-build -Q "$DRVPATH" -o "$OUTDIR/$TESTNAME-test-result" >/dev/null
  then
    echo "! $TESTNAME: run test failed" >> "$SUMMARY"
    return 1
  fi
  echo "· $TESTNAME: $(tail -n1 "$OUTDIR/$TESTNAME-test-result/test-stdout")" | tee -a "$SUMMARY"
}

mkdir -p "$OUTDIR"
echo "# test summary" > "$SUMMARY"

find "$OUTDIR" -name "stackage*" -delete
find "$OUTDIR" -name "hackage*" -delete
rm -f "$OUTDIR/cabal-check.txt"

echo "running cabal-check.."
cabal-check || FAILURE=1

for F in $(find nix/seaaye-cache -name "check-*" | sort)
  do
    NAME=$(echo "$F" | sed -En 's|nix/seaaye-cache/check-.......-(.*)-[^-]*.drv|\1|p')
    echo "running $NAME .."
    run-test "$F" "$NAME" || FAILURE=1
done

echo ""
cat "$SUMMARY"

"$SEAAYE_LIBDIR/scripts/pre-publish-checks.sh" || FAILURE=1

if ((FAILURE == 0))
  then
    echo "SUCCESS!"
    echo "path to sdist to upload:"
    echo "$(nix-build -Q --no-out-link nix/seaaye-cache/sdist.drv)"/*
  else
    echo "some tests failed, not showing sdist path."
fi

echo ""
