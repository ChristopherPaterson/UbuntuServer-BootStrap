SHELL := /usr/bin/env bash

SCRIPTS := scripts/build-template.sh scripts/firstboot-config.sh install.sh
BUILD_DIR := build
EMBED := $(BUILD_DIR)/embed.sh

BUILT_TEMPLATE  := $(BUILD_DIR)/build-template.sh
BUILT_FIRSTBOOT := $(BUILD_DIR)/firstboot-config.sh
BUILT_INSTALL   := $(BUILD_DIR)/install.sh

.PHONY: all lint build clean release demo

all: lint build

# --- lint: shellcheck + shfmt on all source scripts ----------------------

lint:
	@echo "[lint] shellcheck..."
	shellcheck -S warning $(SCRIPTS) $(EMBED)
	@echo "[lint] shfmt..."
	shfmt -d -i 2 -ci -bn $(SCRIPTS) $(EMBED)
	@echo "[lint] passed."

# --- build: embed firstboot, write artefacts + SHA256 --------------------

build: $(BUILT_TEMPLATE) $(BUILT_FIRSTBOOT) $(BUILT_INSTALL)
	@echo "[build] done — artefacts in $(BUILD_DIR)/"

$(BUILT_TEMPLATE): scripts/build-template.sh scripts/firstboot-config.sh $(EMBED)
	@chmod +x $(EMBED)
	@$(EMBED) scripts/build-template.sh scripts/firstboot-config.sh $@
	@sha256sum $@ | awk '{print $$1}' > $@.sha256
	@echo "[build] $@ — SHA256: $$(cat $@.sha256)"

$(BUILT_FIRSTBOOT): scripts/firstboot-config.sh
	@cp $< $@
	@sha256sum $@ | awk '{print $$1}' > $@.sha256
	@echo "[build] $@ — SHA256: $$(cat $@.sha256)"

$(BUILT_INSTALL): install.sh
	@cp $< $@
	@sha256sum $@ | awk '{print $$1}' > $@.sha256
	@echo "[build] $@ — SHA256: $$(cat $@.sha256)"

# --- clean: wipe build artefacts, keep .gitkeep and embed.sh -------------

clean:
	@find $(BUILD_DIR) -maxdepth 1 -type f \
	  ! -name '.gitkeep' ! -name 'embed.sh' -delete
	@echo "[clean] done."

# --- release: lint → build → validate changelog → tag → push ------------

release:
ifndef VERSION
	$(error VERSION is required: make release VERSION=x.y.z)
endif
	@echo "[release] v$(VERSION)"
	@$(MAKE) lint
	@$(MAKE) build
	@grep -q "## \[$(VERSION)\]" CHANGELOG.md \
	  || { echo "ERROR: CHANGELOG.md has no section for v$(VERSION)"; exit 1; }
	@git diff --exit-code > /dev/null \
	  || { echo "ERROR: working tree is dirty — commit changes first"; exit 1; }
	git tag -a "v$(VERSION)" -m "Release v$(VERSION)"
	git push origin "v$(VERSION)"
	@echo "[release] tagged and pushed v$(VERSION)"

# --- demo: generate README GIF via vhs (optional) -------------------------

demo: docs/demo.tape
	vhs docs/demo.tape
