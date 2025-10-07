# Makefile for setting up local development environment for Spotpear Scratch OpenBlock
# Assumes you have git and npm installed, and ssh keys set up for github access
# Also assumes you have mkcert installed for https certs
# Tested on Fedora 41

HOST=$(shell hostname -I | cut -f1 -d' ')

# Obtain ESP, tool chain for micropython with lvgl, and patch with our board
firmware-setup:
	( cd board_firmware/lv_micropython ; make all )

firmware-rebuild:
	( cd board_firmware/lv_micropython ; make rebuild )

# Copy over firmware from boot loader to the VM for automated flashing
firmware-copy:
	cp board_firmware/lv_micropython/ports/esp32/build-SPOTPEARC3/bootloader/bootloader.bin  openblock-vm/src/spotpear_micropython_bl.firmware
	cp board_firmware/lv_micropython/ports/esp32/build-SPOTPEARC3/micropython.bin  openblock-vm/src/spotpear_micropython_mp.firmware
	cp board_firmware/lv_micropython/ports/esp32/build-SPOTPEARC3/partition_table/partition-table.bin  openblock-vm/src/spotpear_micropython_pt.firmware


# Get started with getting right branches and repos
clone:
	git submodule update --init --recursive

	#git clone git@github.com:Spotpear-Scratch/openblock-gui.git -b spotpear
	#git clone git@github.com:Spotpear-Scratch/openblock-l10n.git -b spotpear
	#git clone git@github.com:Spotpear-Scratch/openblock-blocks.git -b spotpear
	#git clone git@github.com:Spotpear-Scratch/openblock-vm.git -b webserial

# Now edit the gui to fix the repo locations to come from local fs
# makes development easier, dont check this in
setup-dev-link:
	sed -i 's|github:Spotpear-Scratch/openblock-l10n#spotpear|../openblock-l10n|g' openblock-blocks/package.json

	sed -i 's|github:Spotpear-Scratch/openblock-l10n#spotpear|../openblock-l10n|g' openblock-vm/package.json
	sed -i 's|github:Spotpear-Scratch/openblock-blocks#spotpear|../openblock-blocks|g' openblock-vm/package.json

	sed -i 's|github:Spotpear-Scratch/openblock-l10n#spotpear|../openblock-l10n|g' openblock-gui/package.json
	sed -i 's|github:Spotpear-Scratch/openblock-blocks#spotpear|../openblock-blocks|g' openblock-gui/package.json
	sed -i 's|github:Spotpear-Scratch/openblock-vm#webserial|../openblock-vm|g' openblock-gui/package.json


install-all:
	( cd openblock-l10n ; NODE_OPTIONS=--openssl-legacy-provider npm install --verbose )
	( cd openblock-blocks ; HOST=$(HOST) NODE_OPTIONS=--openssl-legacy-provider npm install --verbose )
	( cd openblock-vm ; HOST=$(HOST) NODE_OPTIONS=--openssl-legacy-provider npm install --verbose )
	( cd openblock-gui ; HOST=$(HOST) NODE_OPTIONS=--openssl-legacy-provider npm install --verbose)


.ONESHELL: pull-%

pull-%:
	@cd openblock-$*
	pwd
	@echo "Stashing current changes..."
	@git stash push --include-untracked -m "Pre-update-$(shell date +%F-%H%M)" || (echo "Failed to stash changes. Aborting." && exit 1)

	@echo "Fetching latest changes..."
	@git fetch --all --prune || (echo "Failed to fetch remote branches. Aborting." && git stash pop || true && exit 1)

	@echo "Pulling latest changes from remote..."
	@git pull --ff-only || (echo "Failed to pull with fast-forward. Aborting." && git stash pop || true && exit 1)

	@if [ -z "$(git stash list)" ] ; then echo "Nothing to pop from stash..."  ; else $(MAKE) -C ../Makefile apply-stash ; fi

apply-stash:
	@echo "Applying stashed changes..."
	@if git stash pop; then \
		echo "Stashed changes applied successfully."; \
	else \
		REPO_NAME=$(shell basename `git rev-parse --show-toplevel`); \
		echo "!!! CONFLICT DETECTED IN REPO: $$REPO_NAME !!!"; \
		echo "Manual intervention is required. Stash was not dropped and can be reapplied with 'git stash pop'."; \
		exit 1; \
	fi

	@echo "Update complete."

pull-all: pull-l10n pull-blocks pull-vm pull-gui


build-l10n:
	( cd openblock-l10n ; HOST=$(HOST) NODE_OPTIONS=--openssl-legacy-provider npm run prepare --verbose )

build-blocks:
	( cd openblock-blocks ; HOST=$(HOST) NODE_OPTIONS=--openssl-legacy-provider npm run prepare --verbose )

build-vm:
	( cd openblock-vm ; HOST=$(HOST) NODE_OPTIONS=--openssl-legacy-provider npm run prepare --verbose )

# Now build the dependencies that are made local
build-all: build-l10n build-blocks build-vm

# Install https certs, and build and run local
build-gui:
	( cd openblock-gui ; mkcert localhost 127.0.0.1 )
	( cd openblock-gui ; mkcert lanhost $HOST)
	( cd openblock-gui ; HOST=$(HOST) PORT=8801 NODE_OPTIONS=--openssl-legacy-provider npm start --verbose)

deploy:
	( cd openblock-gui ; rm -rf openblock-gui/node_modules/.cache/gh-pages ; NODE_OPTIONS=--openssl-legacy-provider npm run build ; NODE_OPTIONS=--openssl-legacy-provider npm run deploy )
