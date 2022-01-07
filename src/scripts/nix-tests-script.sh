#!/bin/bash

IFS=$'\n' LARGEDERIVS=$(du -md1 /nix/store/ | grep -E "^[0-9]{3,}" | head -n -1 | sed 's/^[0-9]*[ \t]*//' | sort)
# IFS=$'\n' ROOTS=$(nix-store --gc --print-roots | grep -v -E '^/proc|^{temp')

# nix-store --query --roots 
# LOCAL ROOTLOC=${LINE% -> *}
# LOCAL ROOTDRV=${LINE#* -> } 

for LINE in $LARGEDERIVS
  do
  echo "$LINE"
  IFS=$'\n' ROOTS=$(nix-store --query --roots "$LINE")
  for R in $ROOTS
  do
    echo '  ' "$R"
  done
done

# nix-du -s=100MB | tred | dot -Tpdf > store.pdf
