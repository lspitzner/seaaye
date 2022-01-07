{ package-name
, target-name
, nixpkgs
, cleanedSource
, stackFile
, pkg-def-extras ? []
, ghc-ver
, module-flags
# , cabal-install
# , ghcid
}:
let
  # package-nix = nixpkgs.haskell-nix.callStackToNix {
  #   name = package-name;
  #   src = cleanedSource;
  #   stackYaml = stackFile;
  # };
  package-nix = nixpkgs.haskell-nix.callStackToNix {
    name = package-name;
    src = cleanedSource;
    stackYaml = stackFile;
  };
  package-plan = nixpkgs.haskell-nix.importAndFilterProject package-nix;
  generatedCache = nixpkgs.haskell-nix.genStackCache {
    src = cleanedSource;
    stackYaml = stackFile;
  };
  hsPkgs = (nixpkgs.haskell-nix.mkStackPkgSet {
    stack-pkgs = package-plan;
    pkg-def-extras = pkg-def-extras;
    modules = [ (nixpkgs.haskell-nix.mkCacheModule generatedCache)
                { packages.${package-name}.src = nixpkgs.haskell-nix.cleanSourceHaskell { src = cleanedSource; }; }
                { packages.${package-name}.preCheck = ''
                    # echo resolver-is-stackage
                  ''; }
              ] ++ module-flags;
  }).config.hsPkgs;
in rec {
  inherit package-nix package-plan hsPkgs nixpkgs;
  "${package-name}" = hsPkgs.${package-name};
  checks = hsPkgs.${package-name}.checks;
  allComponents = nixpkgs.linkFarm
    "allComponents"
    (builtins.map
      (x: { name = x.name; path = x; })
      (nixpkgs.haskell-nix.haskellLib.getAllComponents hsPkgs.${package-name}));

  shell = hsPkgs.shellFor {
    name = "${package-name}-shell-for-${target-name}";
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

    tools = { ghcid = "0.8.7"; cabal = "3.4.0.0"; };

    # Some you may need to get some other way.
    # TODO probably should define these in generic.nix to pass them into
    # hackage+stackage paths.
    buildInputs = with nixpkgs.haskellPackages;
      [ nixpkgs.bashInteractive
        nixpkgs.nix
      ];

    # Prevents cabal from choosing alternate plans, so that
    # *all* dependencies are provided by Nix.
    exactDeps = true;
  };
}
