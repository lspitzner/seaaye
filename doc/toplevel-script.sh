#!/bin/bash

# This file is a template for the entry-point of the seaaye utility.
# It will serve
#   1) to configure which version of seaaye gets used,
#   2) to configure per-project config, e.g. which ghc versions to
#      test,
#   3) as the entrypoint to seaaye functionality.
#
# As a user, follow these steps to start using seaaye in a new project:
#
# 1) Copy this file to the top-level of your project,
#    e.g. with the target name "build".
# 2) Update the version (SEAAYE_VERSION) variable to the latest available
#    (it is the commit hash).
# 3) Modify the NIX_CONFIG contents as desired. As you may guess it is
#    a nix expression.
# 4) If necessary, apply `chmod +x` to the file you just edited
# 5) You should be able to use seaaye's features now, by invoking this file.
#    For example:
#
#    `./build shell` to enter the project default shell
#    `./build clean` to clean intermediate/cached files
#    `./build ci` to build/test all configurations
#
# See the seaaye README for a full list of available commands.


set -e

###############################
# START OF PER-PROJECT SETTINGS
###############################
SEAAYE_VERSION=25d6ed322afe27fcaccef24707079c5b369479ce
export NIX_CONFIG=$(cat \
<<EOF
{ package-name = "my-awesome-package";
  targets =
  { 
    hackage-8-06 = {
      resolver = "hackage";
      index-state = "2021-07-01T00:00:00Z";
      ghc-ver = "ghc865";
    };
    hackage-8-08 = {
      resolver = "hackage";
      index-state = "2021-07-01T00:00:00Z";
      ghc-ver = "ghc884";
      enabled = false;     # haskell-nix does provide a pre-built ghc for this
                           # version, at least not on a stable nixpkgs branch.
                           # Can enable, but be prepared to sit through a
                           # bootstrap of ghc (same goes for very recent ghc
                           # versions)
    };
    hackage-8-10 = {
      resolver = "hackage";
      index-state = "2021-07-01T00:00:00Z";
      ghc-ver = "ghc8107";
    };
    stackage-8-06 = {
      resolver = "stackage";
      stackFile = "stack-8-6.yaml";        # This file needs to exist
                                           # in the repo
      ghc-ver = "ghc865";
      enabled = false;
    };
  };
  module-flags = [
    # N.B.: There are haskell-nix module options. See the haskell-nix docs
    #       for details. Also, be careful about typos: In many cases you
    #       will not get errors but the typo'd flag will just not have any
    #       effect!
    { packages.my-package.flags.my-package-examples-examples = true; }
  ];
  default-target = "hackage-8-06";
  # local-config-path = ./nix/local-config.nix;
}
EOF
)
###############################
# END OF PER-PROJECT SETTINGS #
###############################

# only touch things below if you know what you are doing

SEAAYE_SOURCE="https://github.com/lspitzner/seaaye/archive/$SEAAYE_VERSION.tar.gz"
SEAAYE_STORE=$(nix-instantiate --expr "builtins.fetchTarball $SEAAYE_SOURCE" --eval --json | jq -r)
nix-store -r "$SEAAYE_STORE" --indirect --add-root nix/seaaye >/dev/null
export SEAAYE_LOCAL_CONFIG_PATH=$(nix-instantiate --eval --strict -E "$NIX_CONFIG" -A local-config-path 2>/dev/null)
export SEAAYE_INVOKER_PATH="$0"
export SEAAYE_MAKEFILE=$(realpath nix/seaaye/Makefile)

# make -f nix/seaaye/new-Makefile "$@"
case "$@" in
  repl|nix-repl|"nix repl")
    nix repl --arg base-config "$NIX_CONFIG" nix/seaaye/main.nix
    ;;
  *)
    make -f nix/seaaye/Makefile "$@"
    ;;
esac
