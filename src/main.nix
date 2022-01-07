let
  importLocalOrElse = maybePath: otherwise:
    if builtins.pathExists maybePath then import maybePath else otherwise;
  tryImportOrElse = path: otherwise:
    let x = builtins.tryEval (import path);
    in if x.success
      then x.value
      else otherwise;
  haskellNixSrc = builtins.fetchTarball
      https://github.com/input-output-hk/haskell.nix/archive/e3933cbb701e5bc61c18f620a4fd43c55f5c026e.tar.gz;
  haskellNix = import haskellNixSrc { version = 2; };
  nixpkgsSrc = haskellNix.sources.nixpkgs-2105;
  nixpkgsUser = tryImportOrElse <iohk-nixpkgs>
    (importLocalOrElse (../iohk-nixpkgs.nix)
    (import nixpkgsSrc haskellNix.nixpkgsArgs));
in
{ base-config, location }:
let
  configLocal = if base-config ? local-config-path
    then importLocalOrElse (base-config.local-config-path) {}
    else {};
  nixpkgs = let
    tempMerged = base-config // configLocal;
  in if tempMerged ? nixpkgs then tempMerged.nixpkgs else nixpkgsUser;
  config = nixpkgs.lib.recursiveUpdate base-config configLocal;
  gitignoreSrc = nixpkgs.fetchFromGitHub {
    owner = "hercules-ci";
    repo = "gitignore.nix";
    rev = "c4662e662462e7bf3c2a968483478a665d00e717";
    sha256 = "sha256:1npnx0h6bd0d7ql93ka7azhj40zgjp815fw2r6smg8ch9p7mzdlx";
  };
  inherit (import gitignoreSrc { inherit (nixpkgs) lib; }) gitignoreSource gitignoreFilter;
  getConfigOrElse = k: default: if builtins.hasAttr k config
    then builtins.getAttr k config
    else default;
in
assert nixpkgs.lib.asserts.assertMsg
  (config.seaaye-spec == 1)
  ''
    seaaye config spec version mismatch!
    seaaye binary supports version 1, local config has ${toString config.seaaye-spec}.
  '';
rec {
  inherit (import <util.nix>) d;
  inherit config nixpkgs;
  # This should take all fields from the config that are serializable
  simplified-config = builtins.intersectAttrs {
    seaaye-spec = true;
    package-name = true;
    targets = true;
    module-flags = true;
    default-target = true;
    local-config-path = true;
    do-check-hackage = true;
    do-check-changelog = true;
    cabal-project-local = true;
  } config // { local-extra-deps = "<lambda>"; };
  cleanedSource = nixpkgs.lib.cleanSourceWith {
    name = config.package-name;
    src = location;
    filter = p: t:
      let baseName = baseNameOf (toString p);
      in gitignoreFilter ./../.. p t
      && baseName != ".gitignore"
      && baseName != "nix"
      && baseName != "ci-out"
      && (builtins.match ".*\.nix" baseName == null);
  };
  localExtraDeps = if builtins.hasAttr "local-extra-deps" config
    then config.local-extra-deps { inherit nixpkgs; }
    else [];
  enabled-target-configs = nixpkgs.lib.attrsets.filterAttrs
      (n: t: if builtins.hasAttr "enabled" t then t.enabled else true)
      config.targets;
  enabled-target-names = builtins.attrNames enabled-targets;
  enabled-targets = builtins.mapAttrs
    (n: target:
      if target.resolver == "hackage" then
        import ./nix/via-hackage.nix {
          inherit nixpkgs;
          cleanedSource = sdist-unpacked;
          pkg-def-extras = localExtraDeps;
          inherit (config) package-name;
          target-name = n;
          inherit (target) ghc-ver index-state;
          module-flags = getConfigOrElse "module-flags" [];
          configureArgs = if target ? configureArgs then target.configureArgs else "";
        }
      else if target.resolver == "stackage" then
        import ./nix/via-stackage.nix {
          inherit nixpkgs;
          cleanedSource = sdist-unpacked;
          inherit (config) package-name;
          target-name = n;
          inherit (target) ghc-ver stackFile;
          module-flags = getConfigOrElse "module-flags" [];
        }
      else throw ("unsupported resolver: " + target.resolver)
    )
    enabled-target-configs;
  default-target = builtins.getAttr config.default-target enabled-targets;
  cabal-check = import ./nix/cabal-check.nix
    { inherit nixpkgs; name = config.package-name; src = cleanedSource; };
  cabal-file-path = sdist-unpacked + "/" + config.package-name + ".cabal";
  # Using this is a bit more precise, but has the downside that sdist-unpacked
  # changes when more targets get enabled (and more stack.yamls added).
  # stack-yaml-paths = builtins.concatMap
  #   (c: if c ? stackFile
  #     then [(builtins.toPath (cleanedSource + "/" + c.stackFile))]
  #     else [])
  #   (builtins.attrValues enabled-target-configs);
  sdist = nixpkgs.stdenvNoCC.mkDerivation {
    name = config.package-name + "-sdist";
    src = cleanedSource;
    buildInputs = [
      nixpkgs.bash
      nixpkgs.cabal-install # could use iohk's cabal-install, but it is slower
                            # to instantiate and needs some ghc-ver. Could use
                            # default-target's, but why is that even necessary?
    ];
    phases = [ "unpackPhase" "buildPhase" ];
    buildPhase = ''
      mkdir -p $out
      cabal sdist -o $out
    '';
  };
  sdist-unpacked = nixpkgs.stdenvNoCC.mkDerivation {
    name = config.package-name + "-sdist-unpacked";
    src = cleanedSource;
    buildInputs = [
      nixpkgs.bash
      nixpkgs.gnutar
    ];
    phases = [ "buildPhase" ];
    buildPhase = ''
      mkdir -p "$out"
      tar -xz -f "${sdist}"/*.tar.gz --strip-components=1 -C "$out"
      for f in "$src"/stack*.yaml; do cp "$f" "$out"; done
      ${let local = getConfigOrElse "cabal-project-local" "";
        in if local == "" then "" else ''
          echo -n "${local}" > "$out/cabal.project.local"
        ''
      }
    '';
  };
  all-shells = builtins.mapAttrs
    (n: target:
      target.shell
    )
    enabled-targets;
  all-package-nixs = builtins.mapAttrs
    (n: target: target.package-nix.projectNix )
    enabled-targets;
  all-checks = builtins.mapAttrs
    (n: target: target.checks )
    enabled-targets
    // { inherit cabal-check sdist sdist-unpacked; };
  all-libs = builtins.mapAttrs
    (n: target: target.${config.package-name}.components.library )
    enabled-targets;
  nix-root-ghcs = nixpkgs.lib.unique (
    nixpkgs.lib.mapAttrsToList (n: target: target.ghc-ver) enabled-target-configs
  );
  haskell-nix-roots =
    builtins.concatMap
      (ghcver: [ (nixpkgs.haskell-nix.roots ghcver)
                 (nixpkgs.haskell-nix.tool ghcver "ghcid" "0.8.7")
                 (nixpkgs.haskell-nix.tool ghcver "cabal" "3.4.0.0")
               ])
      nix-root-ghcs;
  ghc-shell = builtins.mapAttrs
    (n: thisghc:
      nixpkgs.mkShell {
        nativeBuildInputs = [ nixpkgs.bashInteractive thisghc ];
      }
    )
    nixpkgs.haskell-nix.compiler;
}
