let
  importOrElse = maybePath: otherwise:
    if builtins.pathExists maybePath then import maybePath else otherwise;
  haskellNixSrc = builtins.fetchTarball
      https://github.com/input-output-hk/haskell.nix/archive/01fd15957e550737a8109295c5117f6ec26d9abd.tar.gz;
  haskellNix = import haskellNixSrc { version = 2; };
  nixpkgsSrc = haskellNix.sources.nixpkgs-2003;
  nixpkgsLocal = importOrElse ./nixpkgs.nix
    (import nixpkgsSrc haskellNix.nixpkgsArgs);
in
{ package-name
, nixpkgs ? nixpkgsLocal
, targets
, nix-root-ghcs
, module-flags
, default-resolver
, ...
}:
let
  gitignoreSrc = nixpkgs.fetchFromGitHub {
    owner = "hercules-ci";
    repo = "gitignore.nix";
    rev = "c4662e662462e7bf3c2a968483478a665d00e717";
    sha256 = "sha256:1npnx0h6bd0d7ql93ka7azhj40zgjp815fw2r6smg8ch9p7mzdlx";
  };
  inherit (import gitignoreSrc { inherit (nixpkgs) lib; }) gitignoreSource gitignoreFilter;
  cleanedSource = importOrElse ./nix/materialized/cleaned-source.nix
    (nixpkgs.lib.cleanSourceWith {
      name = package-name;
      src = ./../..;
      filter = p: t:
        let baseName = baseNameOf (toString p);
        in gitignoreFilter ./../.. p t
        && baseName != ".gitignore"
        && baseName != "nix"
        && baseName != "ci-out"
        && (builtins.match ".*\.nix" baseName == null);
    });
  localExtraDeps = importOrElse ./local-extra-deps.nix (_: []) {inherit nixpkgs;};
  cabal-install = (nixpkgs.haskell-nix.hackage-package {
    name = "cabal-install";
    version = "3.2.0.0";
    compiler-nix-name = "ghc8102";
    index-state = "2020-08-10T00:00:00Z";
    # Invalidate and update if you change the version or index-state
    plan-sha256 = "1s5c3s7jsaf1arqgz2z7ng0nym83vsinm69lm8wvhpk5rdpfhbld";
  }).components.exes.cabal;
  ghcid = (nixpkgs.haskell-nix.hackage-package {
    name = "ghcid";
    version = "0.8.7";
    compiler-nix-name = "ghc8102";
    index-state = "2020-08-10T00:00:00Z";
    # inherit compiler-nix-name index-state checkMaterialization;
    # Invalidate and update if you change the version or index-state
    plan-sha256 = "1ympqxfww352l2pnk59134rd3k3dxp7pb8jgpcj9z4q1ddr6h5v6";
  }).components.exes.ghcid;
  args = {
    inherit nixpkgs;
    inherit cleanedSource;
    inherit ghcid;
    inherit cabal-install;
    pkg-def-extras = localExtraDeps;
  };
  inherit (builtins) hasAttr;
  concatAttrs = attrList: nixpkgs.lib.fold (x: y: x // y) {} attrList;
in
assert nixpkgs.lib.assertMsg (hasAttr "haskell-nix" nixpkgs) "need iohk haskell-nix overlay!";
let
  versions =
    concatAttrs
      (builtins.map
        (t: {
          "${t.name}" = import ./via-hackage.nix (args // {
            inherit package-name module-flags;
            inherit (t) ghc-ver index-state;
            configureArgs = if t ? configureArgs then t.configureArgs else "";
            pkgsPath = ../materialized + "/${t.name}" + /default.nix;
          });
        })
        targets.hackage
      ) 
    //
    concatAttrs
      (builtins.map
        (t: {
          "${t.name}" = import ./via-stackage.nix (args // {
            inherit package-name module-flags;
            inherit (t) stackFile;
            pkgsPath = ../materialized + "/${t.name}" + /pkgs.nix;
          });
        })
        targets.stackage
      );
in
versions // rec {
  inherit package-name;
  inherit cleanedSource;
  inherit haskellNixSrc haskellNix nixpkgsSrc;
  inherit nixpkgs;
  inherit ghcid;
  inherit cabal-install;
  default = versions.${default-resolver};
  nix-tools-shell = nixpkgs.haskellPackages.shellFor {
    packages = _: [];
    buildInputs = [
      nixpkgs.haskell-nix.nix-tools.ghc865
    ];
  };
  roots = nixpkgs.linkFarm "haskell-nix-roots"
    (builtins.map
      (ghcver:
        { name = "haskell-nix-roots-" + ghcver;
          path = nixpkgs.haskell-nix.roots ghcver;
        }
      )
      nix-root-ghcs
    );
}