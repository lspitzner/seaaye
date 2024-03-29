JSON := $(shell nix-instantiate --read-write-mode --eval --strict --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" "$$SEAAYE_LIBDIR/main.nix" -A 'simplified-config' --json)
SEAAYE_CONFIG_JSON := ${JSON}
export SEAAYE_CONFIG_JSON
GITFILES := $(shell git ls-files | grep -v "^nix" | xargs ls -1 2>/dev/null)
# CLEANED_SOURCE = $(shell nix-instantiate --read-write-mode --eval --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
# 	  "$$SEAAYE_LIBDIR/main.nix" -A 'cleanedSource.outPath')

ifeq (run,$(firstword $(MAKECMDGOALS)))
  # use the rest as arguments for "run"
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  # ...and turn them into do-nothing targets
  $(eval $(RUN_ARGS):dummy;@:)
endif

.PHONY: help
help:
	@"$$SEAAYE_LIBDIR/scripts/print-help.sh"

dummy:

.PHONY: clean
clean:
	rm -rf nix/seaaye-cache
	rm -rf nix/ci-out

.PHONY: clean-all
clean-all: clean
	rm -rf nix/gcroots

.PHONY: targets
targets:
	@nix-instantiate --read-write-mode --eval --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
	  "$$SEAAYE_LIBDIR/main.nix" -A 'enabled-target-names'

.PHONY: shells
shells: nix/seaaye-cache/shell-drvs-marker

.PHONY: shell
shell:
	$(eval DEFAULTTARGET=$(shell jq -r '."default-target"' <<< '${JSON}'))
	@+$(MAKE) -s -f $(SEAAYE_LIBDIR)/Makefile-shell nix/seaaye-cache/shell-for-${DEFAULTTARGET}.marker
	@nix-shell nix/seaaye-cache/shell-for-${DEFAULTTARGET}.drv

.PHONY: run
run:
	$(eval DEFAULTTARGET=$(shell jq -r '."default-target"' <<< '${JSON}'))
	@+$(MAKE) -s -f $(SEAAYE_LIBDIR)/Makefile-shell nix/seaaye-cache/shell-for-${DEFAULTTARGET}.marker
	@nix-shell nix/seaaye-cache/shell-for-${DEFAULTTARGET}.drv --run "$(RUN_ARGS)"

.PHONY: shell-%
shell-%: $(SEAAYE_INVOKER_PATH) $(SEAAYE_CONFIG_PATH) $(SEAAYE_LOCAL_CONFIG_PATH) $(SEAAYE_LIBDIR)/main.nix $(SEAAYE_LIBDIR)/nix/*.nix $(SEAAYE_LOCATION)/*.cabal
	@+$(MAKE) -s -f $(SEAAYE_LIBDIR)/Makefile-shell nix/seaaye-cache/shell-for-$*.marker
	@nix-shell nix/seaaye-cache/shell-for-$*.drv

nix/seaaye-cache/shell-for-%.marker: $(SEAAYE_INVOKER_PATH) $(SEAAYE_CONFIG_PATH) $(SEAAYE_LOCAL_CONFIG_PATH) $(SEAAYE_LIBDIR)/main.nix $(SEAAYE_LIBDIR)/nix/*.nix $(SEAAYE_LOCATION)/*.cabal
	mkdir -p ./nix/seaaye-cache/
#	$(eval GHCVER=$(shell echo '${JSON}' | jq -r '.targets."$*"."ghc-ver"'))
#	$(eval RESOLVER=$(shell echo '${JSON}' | jq -r '.targets."$*"."resolver"'))
	nix-instantiate --read-write-mode --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
		--add-root ./nix/seaaye-cache/shell-for-$*.drv --indirect \
		"$$SEAAYE_LIBDIR/main.nix" -A 'enabled-targets."$*".shell'
	touch ./nix/seaaye-cache/shell-for-$*.marker

nix/seaaye-cache/shell-drvs-marker: $(SEAAYE_INVOKER_PATH) $(SEAAYE_CONFIG_PATH) $(SEAAYE_LOCAL_CONFIG_PATH) $(SEAAYE_LIBDIR)/main.nix $(SEAAYE_LIBDIR)/nix/*.nix
	mkdir -p ./nix/seaaye-cache/
	cd ./nix/seaaye-cache && find -type l -name "shell*" -delete
	cd ./nix/seaaye-cache && find -name "shell*.marker" -delete
	nix-instantiate --read-write-mode --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
	  --add-root ./nix/seaaye-cache/shells --indirect \
	  "$$SEAAYE_LIBDIR/main.nix" -A 'all-shells'
	cd ./nix/seaaye-cache && \
	  find -type l -name "shell*" | \
	    xargs -t -I__ -- bash -c 'ln -s $$(readlink __) $$(readlink __ | sed "s/.*shell-for/shell-for/") && touch $$(readlink __ | sed -E "s|.*(shell-for.*).drv|\1.marker|")'
	touch nix/seaaye-cache/shell-drvs-marker

nix/seaaye-cache/cabal-check-drv-marker: $(SEAAYE_INVOKER_PATH) $(SEAAYE_CONFIG_PATH) $(SEAAYE_LOCAL_CONFIG_PATH) $(SEAAYE_LIBDIR)/main.nix $(SEAAYE_LIBDIR)/nix/*.nix $(GITFILES)
	mkdir -p ./nix/seaaye-cache/
	rm ./nix/seaaye-cache/cabal-check.drv || true
	nix-instantiate --read-write-mode --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
	  --add-root ./nix/seaaye-cache/cabal-check.drv --indirect \
	  "$$SEAAYE_LIBDIR/main.nix" -A 'cabal-check'
	touch nix/seaaye-cache/cabal-check-drv-marker

.PHONY: cabal-check
cabal-check: nix/seaaye-cache/cabal-check-drv-marker
	@nix-build nix/seaaye-cache/cabal-check.drv --no-out-link 1>/dev/null \
	  && echo "cabal check: success" || echo "cabal check: failure"

nix/seaaye-cache/all-checks-marker: $(SEAAYE_INVOKER_PATH) $(SEAAYE_CONFIG_PATH) $(SEAAYE_LOCAL_CONFIG_PATH) $(SEAAYE_LIBDIR)/main.nix $(SEAAYE_LIBDIR)/nix/*.nix $(GITFILES)
	@mkdir -p ./nix/seaaye-cache
	@cd ./nix/seaaye-cache && find -type l -name "all-checks*" -delete
	@cd ./nix/seaaye-cache && find -type l -name "check-*" -delete
	nix-instantiate --read-write-mode --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
	  --add-root ./nix/seaaye-cache/all-checks --indirect \
	  "$$SEAAYE_LIBDIR/main.nix" -A 'all-checks'
	cd ./nix/seaaye-cache && \
	  find -type l -name "all-checks*" | \
	    xargs -rL1 "$$SEAAYE_LIBDIR/scripts/check-drv-renamer.sh"
	touch nix/seaaye-cache/all-checks-marker

.PHONY: ci
ci: nix/seaaye-cache/all-checks-marker
	@"$$SEAAYE_LIBDIR//scripts/ci.sh"

.PHONY: build-libs
build-libs: $(SEAAYE_INVOKER_PATH) $(SEAAYE_CONFIG_PATH) $(SEAAYE_LOCAL_CONFIG_PATH) $(SEAAYE_LIBDIR)/main.nix $(SEAAYE_LIBDIR)/nix/*.nix $(GITFILES)
	nix-instantiate --read-write-mode --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
	  --add-root ./nix/gcroots/all-lib-drv --indirect \
	  "$$SEAAYE_LIBDIR/main.nix" -A 'all-libs'

.PHONY: roots
roots:
	rm -r --\
	  nix/gcroots/shell-drv*\
	  nix/gcroots/shell-deps*\
	  nix/gcroots/haskell-nix-root*\
	  nix/gcroots/shell-out*\
	  nix/gcroots/package-nix-drv*\
	  || true

	nix-instantiate --read-write-mode --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
	  --add-root ./nix/gcroots/shell-drv --indirect \
	  "$$SEAAYE_LIBDIR/main.nix" -A 'all-shells'

	nix-store -r $(shell nix-store --query --references nix/gcroots/shell-drv*) --add-root nix/gcroots/shell-deps/dep --indirect
	nix-build nix/gcroots/shell-drv* -o nix/gcroots/shell-out

	nix-instantiate --read-write-mode --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
	  --add-root ./nix/gcroots/haskell-nix-root-drv --indirect \
	  "$$SEAAYE_LIBDIR/main.nix" -A 'haskell-nix-roots'
	nix-build ./nix/gcroots/haskell-nix-root-drv* -o ./nix/gcroots/haskell-nix-root

	nix-instantiate --read-write-mode --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
	  --add-root ./nix/gcroots/package-nix-drv --indirect \
	  "$$SEAAYE_LIBDIR/main.nix" -A 'all-package-nixs'

.PHONY: show-config-json
show-config-json:
	@echo '${JSON}' | jq '.'

.PHONY: show-config
show-config:
	@nix-instantiate --read-write-mode --eval --strict --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
	  "$$SEAAYE_LIBDIR/main.nix" -A 'config'

.PHONY: sdist
sdist:
	@echo $(shell nix-build --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
	  --no-out-link \
	  "$$SEAAYE_LIBDIR/main.nix" -A 'sdist')/*

.PHONY: install
install:
	nix-env -i \
	  --arg base-config "$$SEAAYE_CONFIG_NIX" \
	  --arg location "$$SEAAYE_LOCATION" \
	  -f "$$SEAAYE_LIBDIR/main.nix" \
	  -A 'default-target.allExes'

.PHONY: dump-package-nix-expression
dump-package-nix-expression:
	@nix-instantiate --read-write-mode --eval --quiet --json \
	  --arg base-config "$$SEAAYE_CONFIG_NIX" \
	  --arg location "$$SEAAYE_LOCATION" \
	  "$$SEAAYE_LIBDIR/main.nix" \
	  -A 'default-target.package-nix-expression' | jq -r

.PHONY: sdist-unpacked
sdist-unpacked:
	@ls -l $(shell nix-build --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" \
	  --no-out-link \
	  "$$SEAAYE_LIBDIR/main.nix" -A 'sdist-unpacked')

.PHONY: pre-publish-checks
pre-publish-checks: nix/seaaye-cache/all-checks-marker
	@"$$SEAAYE_LIBDIR/scripts/pre-publish-checks.sh" || true

PHONY: ghc-shell-%
ghc-shell-%:
	nix-shell --arg base-config "$$SEAAYE_CONFIG_NIX" --arg location "$$SEAAYE_LOCATION" "$$SEAAYE_LIBDIR/main.nix" -A 'ghc-shell.ghc$*'
