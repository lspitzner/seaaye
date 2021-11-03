{ package-name
, target-name
, nixpkgs
, cleanedSource
, pkg-def-extras ? []
, ghc-ver
, index-state
, index-sha256 ? null
, plan-sha256 ? null
, materialized ? null
, configureArgs ? ""
, module-flags
}:
let
  package-nix = nixpkgs.haskell-nix.callCabalProjectToNix {
    src = cleanedSource;
    inherit index-state index-sha256 plan-sha256 materialized configureArgs;
    # ghc = nixpkgs.haskell-nix.compiler.${ghc-ver};
    compiler-nix-name = ghc-ver;
  };
  package-plan = nixpkgs.haskell-nix.importAndFilterProject { inherit (package-nix) projectNix sourceRepos src; };
in assert (!(package-plan ? configurationError)); rec {
  inherit package-nix package-plan nixpkgs;

  hsPkgs = 
    let pkg-set = nixpkgs.haskell-nix.mkCabalProjectPkgSet
              { plan-pkgs = package-plan;
                pkg-def-extras = pkg-def-extras;
                modules = [ 
                  { ghc.package = nixpkgs.haskell-nix.compiler.${ghc-ver}; }
                  #  (pkgs.haskell-nix.mkCacheModule generatedCache)
                  { packages.${package-name}.src = nixpkgs.haskell-nix.cleanSourceHaskell { src = cleanedSource; }; }
                  { packages.${package-name}.preCheck = ''
                      # echo resolver-is-hackage
                    ''; }
                ] ++ module-flags;
              };
    in pkg-set.config.hsPkgs;

  ${package-name} = hsPkgs.${package-name};
  # inherit (hsPkgs) "${package-name}";  nix does not like this syntax :-(
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

    # Some common tools can be added with the `tools` argument
    # tools = { cabal = "3.2.0.0"; };
    # See overlays/tools.nix for more details

    tools = { ghcid = "0.8.7"; cabal = "3.4.0.0"; };

    # Some you may need to get some other way.
    buildInputs = with nixpkgs.haskellPackages;
      [ bash nixpkgs.nix ];

    # Prevents cabal from choosing alternate plans, so that
    # *all* dependencies are provided by Nix.
    exactDeps = true;
  };
}
