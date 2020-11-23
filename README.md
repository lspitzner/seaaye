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

1. Place a copy of this repository in `nix/seaaye` (relative to `$MYPROJECT`
   root directory, wherever that may be. The one that contains your
   `foo.cabal`, `stack.yaml`, `package.yaml` files)
2. Create `nix/package-setup.nix` file with appropriate contents
   (TODO document "appropriate")
3. (optional) Create `stack-x-x.yaml` files for the desired GHC versions
   to be tested
4. Run `make -f nix/seaaye/Makefile ci`

(But we should probably provide another wrapper script that encapsulates this
as well..)

To uninstall, well

1. Delete the `nix/seaaye` folder
2. Delete the `nix/materialized` and the `nix/gcroots` folders that contain
   build caches and nix gc roots
3. If desired, run `nix-collect-garbage`. If you are a nix user I assume you
   know what this does. If not, well it should not break anything you care
   about.

## What This Does Not Support

(or aim to support)

- hpack-based projects. It expects a cabal-file
- Arbitrary/custom GHC versions (pre-releases etc.) - unless haskell-nix starts
  supporting those
- Wait, let me generalize that: No GHC versions other than the ones that
  haskell-nix supports. That is, currently: ghc-8.6, ghc-8.8 and ghc-8.10. And
  ghc-8.4 if you are willing to wait for it to bootstrap (it is not cached).
- multiple-package projects (might be possible to support in the future, but
  untested and highly unlikely to work out-of-the-box)
