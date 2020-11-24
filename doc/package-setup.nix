# This file is an example. Copy it over to $MYPROJECT/nix/package-setup.nix
# And adapt the name and the desired resolvers
# (which hackage/stackage/ghc-versions to check)
{ package-name = "my-package";
  targets =
  { hackage = [
      { name = "hackage-8-4";
        ghc-ver = "ghc844";
        index-state = "2020-08-10T00:00:00Z";
        # can define configure args here if desired/required to compile
        # more components.
        # configureArgs = "-fmy-package-examples";
      }
      { name = "hackage-8-6";
        ghc-ver = "ghc865";
        index-state = "2020-08-10T00:00:00Z";
      }
      { name = "hackage-8-8";
        ghc-ver = "ghc883";
        index-state = "2020-08-10T00:00:00Z";
      }
      { name = "hackage-8-10";
        ghc-ver = "ghc8102";
        index-state = "2020-08-10T00:00:00Z";
      }
    ];
    stackage = [
      { name = "stackage-8-4";
        stackFile = "stack-8-4.yaml"; # If the stackFile naming does not match
                                      # the .name this will break the Makefile.
                                      # (TODO)
        ghc-ver = "ghc844";
      }
      { name = "stackage-8-6";
        stackFile = "stack-8-6.yaml";
        ghc-ver = "ghc865";
      }
      { name = "stackage-8-8";
        stackFile = "stack-8-8.yaml";
        ghc-ver = "ghc883";
      }
    ];
  };
  module-flags = [
    { packages.my-package.flags.my-package-examples-examples = true; }
  ];
  default-resolver = "stackage-8-8";
}
