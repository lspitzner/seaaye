#!/bin/bash

cat <<EOF

# seaaye

help             Print this document
clean            Clean cached files, ci-output
clean-all        Clean cached files, ci-output and nix gc roots
targets          Print available (configured+enabled) targets
shell            Enter shell for default target
shell-\$target    Enter shell for specified target
roots            Create nix garbage-collection roots
cabal-check      Run cabal-check
ci               Run all tests, including cabal check and all
                 test-suites of all enabled targets.
                 Print summary of results
EOF
