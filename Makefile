# could use this an access things via jq, e.g. | jq '."package-name"' but
# I am not sure this even is more efficient.
# package-vars := $(shell nix-instantiate --eval nix/seaaye/package-vars.nix -A "package-name" --strict --json)
package-name              := $(shell nix-instantiate --eval --read-write-mode nix/seaaye/package-vars.nix -A "package-name" --strict --json | jq -r)
default-resolver          := $(shell nix-instantiate --eval --read-write-mode nix/seaaye/package-vars.nix -A "default-resolver" --strict --json | jq -r)
all-version-strings       := $(shell nix-instantiate --eval --read-write-mode nix/seaaye/package-vars.nix -A "all-version-strings" --strict --json | jq -c ".[]")
all-materialization-paths := $(shell nix-instantiate --eval --read-write-mode nix/seaaye/package-vars.nix -A "all-materialization-paths" --strict | jq -r)
all-env-paths             := $(shell nix-instantiate --eval --read-write-mode nix/seaaye/package-vars.nix -A "all-env-paths" --strict | jq -r)

.PHONY: ci
ci: all-manual-materializations nix/materialized/cleaned-source.nix
	# echo "should run ci here"
	time env AllVersionStrings="$(all-version-strings)" PACKAGENAME="$(package-name)" nix/seaaye/ci.sh

.PHONY: all-manual-materializations
all-manual-materializations: $(all-materialization-paths)

.PHONY: all-envs
all-envs: nix/materialized/cleaned-source.nix $(all-env-paths)

nix/gcroots/%-envs: nix/*.nix nix/seaaye/*.nix $(package-name).cabal
	rm nix/gcroots/$*-envs*
	nix-build -o "nix/gcroots/$*-envs" nix/seaaye/package-instance.nix -Q -A "\"$*\".allComponentEnvs"

.PHONY: shell-hackage-%
shell-hackage-%: nix/gcroots/hackage-%-shell nix/gcroots/nix-tools-shell
	nix-shell nix/gcroots/hackage-$*-shell

.PHONY: shell-stackage-%
shell-stackage-%: nix/gcroots/stackage-%-shell nix/gcroots/nix-tools-shell
	nix-shell nix/gcroots/stackage-$*-shell

.PHONY: shell
shell: shell-$(default-resolver)

nix/materialized/hackage-%: nix/*.nix nix/seaaye/*.nix $(package-name).cabal
	nix-instantiate nix/seaaye/package-instance.nix -Q -A 'hackage-$*.package-nix.projectNix' --indirect --add-root nix/gcroots/materialized-hackage-$*
	nix-build nix/seaaye/package-instance.nix -Q -A 'hackage-$*.package-nix.projectNix' -o nix/materialized/hackage-$*
	touch nix/materialized/hackage-$*
nix/materialized/stackage-%: nix/*.nix nix/seaaye/*.nix $(package-name).cabal stack-%.yaml nix/gcroots/nix-tools-shell
	GHCRTS= nix-shell nix/seaaye/package-instance.nix -Q -A 'nix-tools-shell' --run "stack-to-nix -o nix/materialized/stackage-$* --stack-yaml stack-$*.yaml"
	touch nix/materialized/stackage-$*

.PHONY: nix/materialized/cleaned-source.nix
nix/materialized/cleaned-source.nix:
	rm nix/materialized/cleaned-source.nix || true
	$(eval CLEANEDSOURCE=$(shell nix-instantiate --eval --read-write-mode nix/seaaye/package-instance.nix -A "cleanedSource.outPath"))
	echo '/. + $(CLEANEDSOURCE)' > nix/materialized/cleaned-source.nix


nix/gcroots/hackage-%-shell: nix/materialized/hackage-%
	nix-instantiate nix/seaaye/package-instance.nix -A 'hackage-$*.shell' --indirect --add-root nix/gcroots/hackage-$*-shell
	touch nix/gcroots/hackage-$*-shell
nix/gcroots/stackage-%-shell: nix/materialized/stackage-%
	nix-instantiate nix/seaaye/package-instance.nix -A 'stackage-$*.shell' --indirect --add-root nix/gcroots/stackage-$*-shell
	touch nix/gcroots/stackage-$*-shell

nix/gcroots/hackage-%-hsPkgs: nix/materialized/hackage-%
	nix-instantiate nix/seaaye/package-instance.nix -A 'hackage-$*.hsPkgs' --indirect --add-root nix/gcroots/hackage-$*-hsPkgs
	touch nix/gcroots/hackage-$*-hsPkgs
nix/gcroots/stackage-%-hsPkgs: nix/materialized/stackage-%
	# nix-instantiate nix/seaaye/package-instance.nix -A 'stackage-$*.hsPkgs' --indirect --add-root nix/gcroots/stackage-$*-hsPkgs
	nix-build nix/seaaye/package-instance.nix -A 'stackage-$*.hsPkgs' -o nix/gcroots/stackage-$*-hsPkgs
	touch nix/gcroots/stackage-$*-hsPkgs

nix/gcroots/nix-tools-shell: nix/seaaye/*.nix
	nix-instantiate nix/seaaye/package-instance.nix -A 'nix-tools-shell' --indirect --add-root nix/gcroots/nix-tools-shell
	nix-instantiate nix/seaaye/package-instance.nix -A "haskellNixSrc" --eval | sed "s/\"//g" | xargs nix-store --indirect --add-root nix/gcroots/haskellNixSrc -r
	nix-build nix/seaaye/package-instance.nix -A "nixpkgsSrc" -o nix/gcroots/nixpkgsSrc
	nix-build nix/seaaye/package-instance.nix -A "ghcid" -o nix/gcroots/ghcid
	nix-build nix/seaaye/package-instance.nix -A "cabal-install" -o nix/gcroots/cabal-install
	touch nix/gcroots/nix-tools-shell

.PHONY: clean-materialized
clean-materialized:
	rm -r -- nix/materialized/

.PHONY: clean-nix-gc
clean-nix-gc:
	rm -r -- nix/gcroots

stack-%.yaml:
	@echo "The operation requires the existence of $@ but it does not exist!"
	@echo "Please set it up and retry."
	@exit 1
