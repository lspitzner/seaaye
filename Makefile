JSON := '$(shell nix-instantiate --eval --strict --arg base-config "$$NIX_CONFIG" ./nix/seaaye/main.nix -A 'simplified-config' --json)'
GITFILES := $(shell git ls-files | grep -v "^nix" | xargs ls -1 2>/dev/null)
# CLEANED_SOURCE = $(shell nix-instantiate --read-write-mode --eval --arg base-config "$$NIX_CONFIG" \
# 	  nix/seaaye/main.nix -A 'cleanedSource.outPath')


.PHONY: help
help:
	@nix/seaaye/scripts/print-help.sh

.PHONY: clean
clean:
	rm -rf nix/seaaye-cache

.PHONY: targets
targets:
	@nix-instantiate --read-write-mode --eval --arg base-config "$$NIX_CONFIG" \
	  nix/seaaye/main.nix -A 'enabled-target-names'

.PHONY: shells
shells: nix/seaaye-cache/shell-drvs-marker

.PHONY: shell
shell:
	$(eval DEFAULTTARGET=$(shell jq -r '."default-target"' <<< ${JSON}))
	@+$(MAKE) -s -f $(SEAAYE_MAKEFILE)-shell nix/seaaye-cache/shell-for-${DEFAULTTARGET}.marker
	@nix-shell nix/seaaye-cache/shell-for-${DEFAULTTARGET}.drv

.PHONY: shell-%
shell-%: $(SEAAYE_INVOKER_PATH) $(SEAAYE_LOCAL_CONFIG_PATH) ./nix/seaaye/*.nix
	@+$(MAKE) -s -f $(SEAAYE_MAKEFILE)-shell nix/seaaye-cache/shell-for-$*.marker
	@nix-shell nix/seaaye-cache/shell-for-$*.drv

nix/seaaye-cache/shell-for-%.marker: $(SEAAYE_INVOKER_PATH) $(SEAAYE_LOCAL_CONFIG_PATH) ./nix/seaaye/*.nix
	mkdir -p ./nix/seaaye-cache/
#	$(eval GHCVER=$(shell echo ${JSON} | jq -r '.targets."$*"."ghc-ver"'))
#	$(eval RESOLVER=$(shell echo ${JSON} | jq -r '.targets."$*"."resolver"'))
	nix-instantiate --read-write-mode --arg base-config "$$NIX_CONFIG" \
		--add-root ./nix/seaaye-cache/shell-for-$*.drv --indirect \
		nix/seaaye/main.nix -A 'enabled-targets."$*".shell'
	touch ./nix/seaaye-cache/shell-for-$*.marker

nix/seaaye-cache/shell-drvs-marker: $(SEAAYE_INVOKER_PATH) $(SEAAYE_LOCAL_CONFIG_PATH) ./nix/seaaye/*.nix
	mkdir -p ./nix/seaaye-cache/
	cd ./nix/seaaye-cache && find -type l -name "shell*" -delete
	cd ./nix/seaaye-cache && find -name "shell*.marker" -delete
	nix-instantiate --read-write-mode --arg base-config "$$NIX_CONFIG" \
	  --add-root ./nix/seaaye-cache/shells --indirect \
	  nix/seaaye/main.nix -A 'all-shells'
	cd ./nix/seaaye-cache && \
	  find -type l -name "shell*" | \
	    xargs -t -I__ -- bash -c 'ln -s $$(readlink __) $$(readlink __ | sed "s/.*shell-for/shell-for/") && touch $$(readlink __ | sed -E "s|.*(shell-for.*).drv|\1.marker|")'
	touch nix/seaaye-cache/shell-drvs-marker

nix/seaaye-cache/cabal-check-drv-marker: $(SEAAYE_INVOKER_PATH) $(SEAAYE_LOCAL_CONFIG_PATH) ./nix/seaaye/*.nix $(GITFILES)
	mkdir -p ./nix/seaaye-cache/
	rm ./nix/seaaye-cache/cabal-check.drv || true
	nix-instantiate --read-write-mode --arg base-config "$$NIX_CONFIG" \
	  --add-root ./nix/seaaye-cache/cabal-check.drv --indirect \
	  nix/seaaye/main.nix -A 'cabal-check'
	touch nix/seaaye-cache/cabal-check-drv-marker

.PHONY: cabal-check
cabal-check: nix/seaaye-cache/cabal-check-drv-marker
	@nix-build nix/seaaye-cache/cabal-check.drv --no-out-link 1>/dev/null \
	  && echo "cabal check: success" || echo "cabal check: failure"

nix/seaaye-cache/all-checks-marker: $(SEAAYE_INVOKER_PATH) $(SEAAYE_LOCAL_CONFIG_PATH) ./nix/seaaye/*.nix $(GITFILES)
	@mkdir -p ./nix/seaaye-cache
	@cd ./nix/seaaye-cache && find -type l -name "all-checks*" -delete
	@cd ./nix/seaaye-cache && find -type l -name "check-*" -delete
	nix-instantiate --read-write-mode --arg base-config "$$NIX_CONFIG" \
	  --add-root ./nix/seaaye-cache/all-checks --indirect \
	  nix/seaaye/main.nix -A 'all-checks'
	cd ./nix/seaaye-cache && \
	  find -type l -name "all-checks*" | \
	    xargs -rL1 ../seaaye/scripts/check-drv-renamer.sh
	touch nix/seaaye-cache/all-checks-marker

.PHONY: ci
ci: nix/seaaye-cache/all-checks-marker
	@nix/seaaye/scripts/ci.sh

.PHONY: build-libs
build-libs: $(SEAAYE_INVOKER_PATH) $(SEAAYE_LOCAL_CONFIG_PATH) ./nix/seaaye/*.nix $(GITFILES)
	nix-instantiate --read-write-mode --arg base-config "$$NIX_CONFIG" \
	  --add-root ./nix/gcroots/all-lib-drv --indirect \
	  nix/seaaye/main.nix -A 'all-libs'

.PHONY: roots
roots:
	rm -r --\
	  nix/gcroots/shell-drv*\
	  nix/gcroots/shell-deps*\
	  nix/gcroots/haskell-nix-root*\
	  nix/gcroots/shell-out*\
	  nix/gcroots/package-nix-drv*\
	  || true

	nix-instantiate --read-write-mode --arg base-config "$$NIX_CONFIG" \
	  --add-root ./nix/gcroots/shell-drv --indirect \
	  nix/seaaye/main.nix -A 'all-shells'

	nix-store -r $(shell nix-store --query --references nix/gcroots/shell-drv*) --add-root nix/gcroots/shell-deps/dep --indirect
	nix-build nix/gcroots/shell-drv* -o nix/gcroots/shell-out

	nix-instantiate --read-write-mode --arg base-config "$$NIX_CONFIG" \
	  --add-root ./nix/gcroots/haskell-nix-root-drv --indirect \
	  nix/seaaye/main.nix -A 'haskell-nix-roots'
	nix-build ./nix/gcroots/haskell-nix-root-drv* -o ./nix/gcroots/haskell-nix-root

	nix-instantiate --read-write-mode --arg base-config "$$NIX_CONFIG" \
	  --add-root ./nix/gcroots/package-nix-drv --indirect \
	  nix/seaaye/main.nix -A 'all-package-nixs'

.PHONY: show-config-json
show-config-json:
	echo ${JSON} | jq '.'

.PHONY: show-config
show-config:
	nix-instantiate --read-write-mode --eval --strict --arg base-config "$$NIX_CONFIG" \
	  nix/seaaye/main.nix -A 'config'
