#!/bin/bash

set -e

SEAAYE_LIBDIR=$(dirname "$0")/../lib/seaaye
if [ -f ./seaaye.nix ]
then
  SEAAYE_CONFIG_PATH=./seaaye.nix
elif [ -f ./nix/seaaye.nix ]
then
  SEAAYE_CONFIG_PATH=./nix/seaaye.nix
else
  echo "could not find seaaye.nix config!"
  exit 1
fi
SEAAYE_CONFIG_NIX=$(cat "$SEAAYE_CONFIG_PATH")
SEAAYE_LOCATION=$(pwd)
export SEAAYE_CONFIG_NIX
export SEAAYE_LIBDIR="$SEAAYE_LIBDIR"
export SEAAYE_LOCATION

# SEAAYE_SOURCE="https://github.com/lspitzner/seaaye/archive/$SEAAYE_VERSION.tar.gz"
# SEAAYE_STORE=$(nix-instantiate --expr "builtins.fetchTarball $SEAAYE_SOURCE" --eval --json | jq -r)
# nix-store -r "$SEAAYE_STORE" --indirect --add-root nix/seaaye >/dev/null
export SEAAYE_CONFIG_PATH
SEAAYE_LOCAL_CONFIG_PATH=$(nix-instantiate --eval --strict -E "$SEAAYE_CONFIG_NIX" -A local-config-path 2>/dev/null || true)
export SEAAYE_LOCAL_CONFIG_PATH
# export SEAAYE_INVOKER_PATH="$0"
# export SEAAYE_MAKEFILE=$(realpath nix/seaaye/Makefile)

case "$@" in
  repl|nix-repl|"nix repl")
    nix repl --arg base-config "$SEAAYE_CONFIG_NIX" --arg location "$SEAAYE_LOCATION" "$SEAAYE_LIBDIR/main.nix"
    ;;
  *)
    make --no-print-directory -f "$SEAAYE_LIBDIR/Makefile" -- "$@"
    ;;
esac
