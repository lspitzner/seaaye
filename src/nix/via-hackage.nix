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

  exes = hsPkgs.${package-name}.components.exes;

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
      [ nixpkgs.bashInteractive nixpkgs.nix ];

    # Prevents cabal from choosing alternate plans, so that
    # *all* dependencies are provided by Nix.
    exactDeps = true;
  };

  package-nix-expression = ''
    let
      haskellNixSrc = builtins.fetchTarball
          https://github.com/input-output-hk/haskell.nix/archive/e3933cbb701e5bc61c18f620a4fd43c55f5c026e.tar.gz;
      haskellNix = import haskellNixSrc { version = 2; };
      nixpkgsSrc = haskellNix.sources.nixpkgs-2105;
    in
    { nixpkgs ? import nixpkgsSrc haskellNix.nixpkgsArgs
    , ghc-ver ? "${ghc-ver}"
    , index-state ? ${nixpkgs.lib.strings.escapeNixString index-state}
    , index-sha256 ? ${nixpkgs.lib.strings.escapeNixString index-sha256}
    , plan-sha256 ? ${nixpkgs.lib.strings.escapeNixString plan-sha256}
    , materialized ? ${nixpkgs.lib.strings.escapeNixString materialized}
    }:
    with nixpkgs;
    let
      gitignoreSrc = nixpkgs.fetchFromGitHub {
        owner = "hercules-ci";
        repo = "gitignore.nix";
        rev = "c4662e662462e7bf3c2a968483478a665d00e717";
        sha256 = "sha256:1npnx0h6bd0d7ql93ka7azhj40zgjp815fw2r6smg8ch9p7mzdlx";
      };
      inherit (import gitignoreSrc { inherit (nixpkgs) lib; }) gitignoreFilter;
      cleanedSource = nixpkgs.lib.cleanSourceWith {
        name = "${package-name}";
        src = ./.;
        filter = p: t:
          let baseName = baseNameOf (toString p);
          in gitignoreFilter ./../.. p t
          && baseName != ".gitignore"
          && baseName != "nix"
          && baseName != "ci-out"
          && (builtins.match ".*\.nix" baseName == null);
      };
      sdist = nixpkgs.stdenvNoCC.mkDerivation {
        name = "${package-name}" + "-sdist";
        src = cleanedSource;
        buildInputs = [ nixpkgs.bash nixpkgs.cabal-install ];
        phases = [ "unpackPhase" "buildPhase" ];
        buildPhase = '''
          mkdir -p $out
          cabal sdist -o $out
        ''';
      };
      sdist-unpacked = nixpkgs.stdenvNoCC.mkDerivation {
        name = "${package-name}" + "-sdist-unpacked";
        src = cleanedSource;
        buildInputs = [
          nixpkgs.bash
          nixpkgs.gnutar
        ];
        phases = [ "buildPhase" ];
        buildPhase = '''
          mkdir -p "$out"
          tar -xz -f "''${sdist}"/*.tar.gz --strip-components=1 -C "$out"
          for f in "$src"/stack*.yaml; do cp "$f" "$out"; done
        ''';
      };
      package-nix = nixpkgs.haskell-nix.callCabalProjectToNix {
        src = sdist-unpacked;
        inherit index-state index-sha256 plan-sha256 materialized;
        compiler-nix-name = ghc-ver;
      };
      package-plan = nixpkgs.haskell-nix.importAndFilterProject { inherit (package-nix) projectNix sourceRepos src; };
      hsPkgs =
        let pkg-set = nixpkgs.haskell-nix.mkCabalProjectPkgSet
                  { plan-pkgs = package-plan;
                    modules = [
                      { ghc.package = nixpkgs.haskell-nix.compiler.''${ghc-ver}; }
                      { packages.${package-name}.src = nixpkgs.haskell-nix.cleanSourceHaskell { src = cleanedSource; }; }
                    ];
                  };
        in pkg-set.config.hsPkgs;
    in hsPkgs.${package-name}.components.exes
  '';
}
