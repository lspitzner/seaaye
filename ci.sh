#!/bin/bash

OUTDIR="nix/ci-out"
SUMMARY="$OUTDIR/0-summary"

# TODO this should be replaced with the default path from package-setup.nix
CABAL_CHECK_ATTRPATH="hackage-8-10"

set -x

mkdir -p "$OUTDIR"
echo "# test summary" > "$SUMMARY"

function build-one {
  local ATTRPATH=$1
  nix-build -o "$OUTDIR/$ATTRPATH-build" nix/seaaye/package-instance.nix -Q -A "\"$ATTRPATH\".allComponents"\
    2> >(tee "$OUTDIR/$ATTRPATH-build.txt" >&2)
  (($? == 0)) || { echo "$ATTRPATH: all-component build failed" >> "$SUMMARY"; return 1; }
  nix-build -o "$OUTDIR/$ATTRPATH-test-result" -Q nix/seaaye/package-instance.nix -A "\"$ATTRPATH\".$PACKAGENAME.checks.tests"
  (($? == 0)) || { echo "$ATTRPATH: run test failed" >> "$SUMMARY"; return 1; }
  echo "$ATTRPATH: $(grep examples "$OUTDIR/$ATTRPATH-test-result/test-stdout")" >> "$SUMMARY"
}

function cabal-check {
  nix-build --no-out-link nix/seaaye/package-instance.nix -A "\"$CABAL_CHECK_ATTRPATH\".cabal-check"\
    2> >(tee "$OUTDIR/cabal-check.txt" >&2)
  (($? == 0)) || { echo "cabal-check: failed" >> "$SUMMARY"; return 1; }
  echo "cabal-check: success" >> "$SUMMARY"
}

find "$OUTDIR" -name "stackage*" -delete
find "$OUTDIR" -name "hackage*" -delete
rm "$OUTDIR/cabal-check.txt"
CLEANEDSOURCE=$(nix-instantiate --eval --read-write-mode nix/seaaye/package-instance.nix -A "cleanedSource.outPath")
(($? == 0)) || exit 1
( eval "cd $CLEANEDSOURCE; find" ) > "$OUTDIR/1-cleanedSource.txt"

echo $AllVersionStrings

for version in $AllVersionStrings; do
  build-one $version
done

cabal-check

cat "$SUMMARY"
