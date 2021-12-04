#!/bin/bash

set -e

FAILURE=0

PACKAGE_NAME=$(jq -r '.["package-name"]' <<< $SEAAYE_CONFIG_JSON)
HACKAGE_CHECK_URL=$(jq -r '.["do-check-hackage"] // ""' <<< $SEAAYE_CONFIG_JSON)
CHANGELOG_CHECK_PATH=$(jq -r '.["do-check-changelog"] // ""' <<< $SEAAYE_CONFIG_JSON)
CABAL_PROJECT_LOCAL=$(jq -r '.["cabal-project-local"]' <<< $SEAAYE_CONFIG_JSON)
SEAAYE_CONFIG_LOCAL=$(jq -r '.["local-config-path"]' <<< $SEAAYE_CONFIG_JSON)

IS_LOCAL=0

if [ "$CABAL_PROJECT_LOCAL" != "null" ]
  then
    echo "! local config us enabled (cabal-project-local), please disable."
    IS_LOCAL=1
fi
if [ "$SEAAYE_CONFIG_LOCAL" != "null" ]
  then
    echo "! local config us enabled (local-config), please disable."
    IS_LOCAL=1
fi

if (($IS_LOCAL))
  then
    exit 1
fi

CABAL_FILE_PATH=$(nix-instantiate --read-write-mode --eval --arg base-config "$NIX_CONFIG" -A "cabal-file-path" nix/seaaye/main.nix --json | jq -r)
SDIST_UNPACKED=$(nix-build -Q --no-out-link nix/seaaye-cache/sdist-unpacked.drv)
PACKAGE_VERSION=$(sed -En 's|^version: *(.*)|\1|Ip' "$CABAL_FILE_PATH")

if [ "$CHANGELOG_CHECK_PATH" ]
  then
    if grep "$PACKAGE_VERSION" -q "$SDIST_UNPACKED/$CHANGELOG_CHECK_PATH"
      then
        echo "· $PACKAGE_VERSION is mentioned in the changelog."
      else
        echo "! $PACKAGE_VERSION is not mentioned in changelog!"
        FAILURE=1
    fi
fi

if [ "$HACKAGE_CHECK_URL" ]
  then
    PREFERRED=$(curl -s -H "accept: application/json" \
      "$HACKAGE_CHECK_URL/package/$PACKAGE_NAME/preferred"
    )
    IS_PUBLISHED=$(
      jq '.["normal-version"] | any(. == "'"$PACKAGE_VERSION"'")' <<< "$PREFERRED"
    )
    if [ "$IS_PUBLISHED" = "true" ]
      then
        echo "! $PACKAGE_NAME-$PACKAGE_VERSION is already present on hackage, needs Bump?!"
        FAILURE=1
      else
        echo "· $PACKAGE_NAME-$PACKAGE_VERSION is not yet on hackage."
    fi
fi

exit $FAILURE
