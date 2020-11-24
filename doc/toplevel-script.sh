#!/bin/bash

# Copy this file to the top-level of your project, e.g. with the target name
# "build". If necessary update the version string (it is the hash of the
# git commit id of this repo).
#
# Then you should be able to
# `./build shell` to enter the project default shell
# `./build ci` to build/test all configurations
# `./build shell-hackage-8-4` to enter a specific configuration's shell

set -e

SEAAYE_VERSION=c183de0b0cceadffd060d8a221f694816910e9c2
SEAAYE_SOURCE="https://github.com/lspitzner/seaaye/archive/$SEAAYE_VERSION.tar.gz"
SEAAYE_STORE=$(nix-instantiate --expr "builtins.fetchTarball $SEAAYE_SOURCE" --eval --json | jq -r)
nix-store -r "$SEAAYE_STORE" --indirect --add-root nix/seaaye >/dev/null
make -f nix/seaaye/Makefile "$@"
