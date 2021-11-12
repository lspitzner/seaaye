#!/bin/bash

set -e

TARGET="$(readlink $1)"
case "$TARGET" in
  *-test-*)
    GHC=$(nix show-derivation "$1" | sed -En 's|^.*(ghc-[0-9.]*)-env.*$|\1|p' | head -n1 )
    RESOLVER=$(nix show-derivation "$1" | sed -En 's|^.*resolver-is-([a-z]*).*$|\1|p')
    SORTINGSTR=$(echo "$GHC" | sed -r ":r;s|\b[0-9]{1,1}\b|0&|g;tr" | sed 's|[-.a-z]||g' )
    GHCNAME=$(echo "$GHC" | sed 's|[-.]||g' )
    TESTNAME=$(echo "$TARGET" | sed -En 's|^.*-test-(.*)-check\.drv|\1|p' )
    # echo "TESTNAME=$TESTNAME, GHC=$GHC, TARGET=$TARGET"
    ln -s "$TARGET" "check-${RESOLVER:0:1}$SORTINGSTR-$RESOLVER-$GHCNAME-$TESTNAME.drv"
    ;;
  *-cabal-check.drv)
    ln -sf "$TARGET" cabal-check.drv
    touch cabal-check-drv-marker
    ;;
  *-sdist.drv)
    ln -sf "$TARGET" sdist.drv
    ;;
  *-sdist-unpacked.drv)
    ln -sf "$TARGET" sdist-unpacked.drv
    ;;
  *)
    echo "I don't know what to do with $TARGET!"
    ;;
esac
