# seaaye

## Context

seaaye is a set of scripts to help with the maintenance of packages written
in haskell

## What Problem Is This Trying To Solve

I find maintaining haskell packages a serious chore. From having to manually
install multiple GHCs, cabal changing its CUI randomly, cabal having commands
that are not idempotent and are otherwise weird, stack making it hard to use
a custom/local GHC, stack making it rather hard to use a custom package set
(latest versions of packages instead of some package snapshot), cabal store
not support garbage collection, stack store not supporting garbage collection,
non-reproducable builds or non-cacheable intermediate results, CI solutions
using some arcane configuration language that has serious quirks, CI solutions
that you cannot test locally etc.

## Goals of This Little Project

- Build with multiple GHC versions
- Check against package-sets both by invoking the cabal solver or
  by relying on a specific stackage snapshot (i.e. support both cabal and
  stack users)
- Support doing all of this locally (i.e. no scripting language that only the
  remote CI service knows how to interpret)
- Have a one-command invokation that re-runs all desired checks
- Have the builds be reproducable
- Cache intermediate results so all but the first build should take a few
  minutes at most
- Support garbage-collecting all out-dated cache contents

## How It Works

- This uses the nix language (nixos.org, see https://nixos.org/manual/nix/stable/#ch-expression-language)
- Makes heavy use of https://github.com/input-output-hk/haskell.nix / https://input-output-hk.github.io/haskell.nix/
- Uses a Makefile and some bash script(s) (eww, I know. But nix IFDs are really
  annoying to handle)

## How to Use

Currently, this is highly experimental and somewhat user-unfriendly.

This **assumes** you have a **working nix setup** and have the
**iohk cache set up**.

The rough idea is this:

1. Install the executable via `nix-env -i -f https://github.com/lspitzner/seaaye/archive/master.tar.gz`
2. Copy `doc/example-seaaye.nix` file over to `./seaaye.nix` in your project.
3. Edit `./seaaye.nix` and replace the obvious parts of the template with
   your actual desired config, e.g. `package-name` should be your local
   package name, you can specify which targets to build.
4. Run
    - `seaaye` to see an overview of available commands
    - `seaaye ci` to build/test all configurations
    - `seaaye shell` to enter a dev shell for your default configuration
    - `seaaye roots` to capture nix garbage-collection roots so your
      next `nix-collect-garbage` run does not delete everything
5. Modify your .gitignore to include the following:

    ~~~~
    /nix/seaaye
    /nix/seaaye-cache
    /nix/gcroots
    /nix/ci-out
    ~~~~

To uninstall,

1. Run `seaaye clean-all` (or delete `nix/seaaye`,`nix/seaaye-cache`,`nix/gcroots`,`nix/ci-out`)
2. Delete the `seaaye` script from your nix env.
3. If desired, run `nix-collect-garbage`.

## How To Specify Resolvers

Resolvers specify how dependency resolution works, i.e. what package versions
are used for the dependencies of the local package. In the haskell ecosystem
there are two approaches to this.

1) Either we use the latest compatible versions (as determined by the version
   bounds specified along the dependencies in the package meta-data) available
   on hackage (this is what the `cabal` tool usually does) - we call this
   resolver "hackage".
   To make the above notion of "latest compatible versions" deterministic there
   exists an argument "index-state" which is a timestamp.
   Also, you can specify which version of ghc to use.

2) Or we use a specific compatible set of package-versions as defined by the
   stackage project. We call this resolver "stackage". For now, this requires
   a `stack-something.yaml` file per stackage snapshot. Please refer to the
   stack documentation for the contents of that file. And while the stackage
   snapshot/resolver implies a specific ghc-version as well, you need to
   specify it along side in the seaaye-target's target config so that the
   appropriate ghc can be made available in the nix-shell for the stackage
   target.

The "template" `toplevel-script.sh` contains examples for both approaches.

## What This Does Not Support

(or aim to support)

- hpack-based projects. It expects a cabal-file
- Actually using stack inside the dev nix-shell. Well, maybe you can get this
  to work somehow, but you won't benefit from caching library dependencies.
  You might be able to use the GHC provided via nix. Maybe.
- Arbitrary/custom GHC versions (pre-releases etc.) - unless haskell-nix starts
  supporting those
- Wait, let me generalize that: No GHC versions other than the ones that
  haskell-nix supports. That is, currently: ghc-8.6, ghc-8.8, ghc-8.10 and
  ghc-9.0 although 8.8 and 9.0 are _not_ cached (you will need to compile
  ghc!)
- multiple-package projects (might be possible to support in the future, but
  untested and highly unlikely to work out-of-the-box)
