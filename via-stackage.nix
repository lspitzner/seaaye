{ package-name
, nixpkgs
, cleanedSource
, stackFile
, pkgsPath
, pkg-def-extras ? []
, module-flags
, cabal-install
, ghcid
}:
let
  # package-nix = nixpkgs.haskell-nix.callStackToNix {
  #   name = package-name;
  #   src = cleanedSource;
  #   stackYaml = stackFile;
  # };
  package-plan = import pkgsPath;
  generatedCache = nixpkgs.haskell-nix.genStackCache {
    src = cleanedSource;
    stackYaml = stackFile;
  };
  hsPkgs = (nixpkgs.haskell-nix.mkStackPkgSet {
    stack-pkgs = package-plan;
    pkg-def-extras = pkg-def-extras;
    modules = [ (nixpkgs.haskell-nix.mkCacheModule generatedCache)
                { packages.${package-name}.src = nixpkgs.haskell-nix.cleanSourceHaskell { src = cleanedSource; }; }
              ] ++ module-flags;
  }).config.hsPkgs;
in rec {
  inherit package-plan hsPkgs nixpkgs;
  "${package-name}" = hsPkgs.${package-name};
  checks = hsPkgs.${package-name}.checks;
  cabal-check = import ./cabal-check.nix
    { inherit nixpkgs; name = package-name; src = cleanedSource; };
  allComponents = nixpkgs.linkFarm
    "allComponents"
    (builtins.map
      (x: { name = x.name; path = x; })
      (nixpkgs.haskell-nix.haskellLib.getAllComponents hsPkgs.${package-name}));
  allComponentEnvs =
    (builtins.map
      (x: x.env)
      (nixpkgs.haskell-nix.haskellLib.getAllComponents hsPkgs.${package-name}));

  shell = hsPkgs.shellFor {
    # Include only the *local* packages of your project.
    packages = ps: [
      ps.${package-name}
    ];

    # Builds a Hoogle documentation index of all dependencies,
    # and provides a "hoogle" command to search the index.
    withHoogle = false;

    # You might want some extra tools in the shell (optional).

    # tools is broken. It starts compiling a different ghc-8.4 than what
    # the rest of the setup is using. Even for the shell of a ghc-8.8
    # environment.. using buildInputs and manual pinning instead for now.
    # tools = { ghcid = "0.8.7"; cabal = "3.2.0.0"; };
    # See overlays/tools.nix for more details

    # Some you may need to get some other way.
    # TODO probably should define these in generic.nix to pass them into
    # hackage+stackage paths.
    buildInputs = with nixpkgs.haskellPackages;
      [ bash
        nixpkgs.nix
        ghcid
        cabal-install
      ];

    # Prevents cabal from choosing alternate plans, so that
    # *all* dependencies are provided by Nix.
    exactDeps = true;
  };
}
