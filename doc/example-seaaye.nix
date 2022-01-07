{ package-name = "my-awesome-package";
  targets =
  { 
    hackage-8-06 = {
      resolver = "hackage";
      index-state = "2021-07-01T00:00:00Z";
      ghc-ver = "ghc865";
    };
    hackage-8-08 = {
      resolver = "hackage";
      index-state = "2021-07-01T00:00:00Z";
      ghc-ver = "ghc884";
      enabled = false;     # haskell-nix does provide a pre-built ghc for this
                           # version, at least not on a stable nixpkgs branch.
                           # Can enable, but be prepared to sit through a
                           # bootstrap of ghc (same goes for very recent ghc
                           # versions)
    };
    hackage-8-10 = {
      resolver = "hackage";
      index-state = "2021-07-01T00:00:00Z";
      ghc-ver = "ghc8107";
    };
    stackage-8-06 = {
      resolver = "stackage";
      stackFile = "stack-8-6.yaml";        # This file needs to exist
                                           # in the repo
      ghc-ver = "ghc865";
      enabled = false;
    };
  };
  module-flags = [
    # N.B.: There are haskell-nix module options. See the haskell-nix docs
    #       for details. Also, be careful about typos: In many cases you
    #       will not get errors but the typo'd flag will just not have any
    #       effect!
    { packages.my-package.flags.my-package-examples-examples = true; }
  ];
  default-target = "hackage-8-06";
  ## Use the below lines to enable more checks.
  ## - check whether the version needs a bump
  ## - check whether there is a changelog entry for the to-be-released version
  # do-check-hackage = "hackage.haskell.org";
  # do-check-changelog = "ChangeLog.md";
  ## Use the below option to override things not intended to be published
  # local-config-path = ./seaaye-local.nix;
  ## Use the below to change cabal/hackage dependency-resolution by adding
  ## an add-hoc cabal.project.local file with the specified contents.
  ## This e.g. makes it possible to add "allow-newer: *:base" to test
  ## stuff with a newly released ghc version.
  # cabal-project-local = "allow-newer: *:base";
}
