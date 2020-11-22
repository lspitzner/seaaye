{ nixpkgs
, name
, src
}:

nixpkgs.buildPackages.runCommand ("${name}-cabal-check") {
    nativeBuildInputs = [ nixpkgs.buildPackages.cabal-install ];
} ''
  cp -r ${src}/* ./
  touch "$out"

  runHook preBuild

  cabal check | tee "$out"

  runHook postBuild
''