DOCKER_IMAGE ?= zmkfirmware/zmk-build-arm:stable
WORKSPACE := /workspace
DOCKER_VOLUMES := -v zmk-zephyr-cache:/root/.cache/zephyr -v zmk-build-cache:/tmp/build

DOCKER_RUN := docker run --rm \
	-v "$(CURDIR)":$(WORKSPACE) \
	-w $(WORKSPACE) \
	$(DOCKER_VOLUMES) \
	$(DOCKER_IMAGE)

WORKSPACE_DIRS := .west zmk zephyr modules bootloader tools optional

BOARD := xiao_ble
SNIPPET := studio-rpc-usb-uart
FIRMWARE_DIR := firmware

.PHONY: all update left right clean pristine flash help fix-perms rebuild

help:
	@echo "Targets:"
	@echo "  all       - build left and right (default)"
	@echo "  left      - build totem_left only"
	@echo "  right     - build totem_right only"
	@echo "  rebuild   - clean and build both halves"
	@echo "  update    - initialize or update west workspace (ZMK, Zephyr, modules)"
	@echo "  flash     - print instructions to flash the .uf2 files"
	@echo "  clean     - remove firmware/ directory"
	@echo "  pristine  - wipe docker build cache (forces full rebuild)"
	@echo "  fix-perms - chown and chmod workspace + firmware to current user"
	@echo "  nuke      - wipe west workspace + docker caches (full reset)"

all: left right

rebuild: clean all

update:
	$(DOCKER_RUN) bash -c "if [ ! -d .west ] || [ ! -d zmk ] || [ ! -d zephyr ]; then west init -l config; fi; west update; west zephyr-export; chmod -R a+rwX $(WORKSPACE_DIRS) 2>/dev/null || true"

left:
	@mkdir -p $(FIRMWARE_DIR)
	$(DOCKER_RUN) bash -c "if [ ! -d .west ] || [ ! -d zmk ] || [ ! -d zephyr ]; then west init -l config; fi; west update; west zephyr-export; chmod -R a+rwX $(WORKSPACE_DIRS) 2>/dev/null || true; west build -s zmk/app -b $(BOARD) -S $(SNIPPET) -d /tmp/build/totem_left -- -DSHIELD=totem_left -DZMK_CONFIG=$(WORKSPACE)/config && cp /tmp/build/totem_left/zephyr/zmk.uf2 $(WORKSPACE)/firmware/totem_left.uf2 && chmod 666 $(WORKSPACE)/firmware/totem_left.uf2"
	@echo "Built $(FIRMWARE_DIR)/totem_left.uf2"

right:
	@mkdir -p $(FIRMWARE_DIR)
	$(DOCKER_RUN) bash -c "if [ ! -d .west ] || [ ! -d zmk ] || [ ! -d zephyr ]; then west init -l config; fi; west update; west zephyr-export; chmod -R a+rwX $(WORKSPACE_DIRS) 2>/dev/null || true; west build -s zmk/app -b $(BOARD) -S $(SNIPPET) -d /tmp/build/totem_right -- -DSHIELD=totem_right -DZMK_CONFIG=$(WORKSPACE)/config && cp /tmp/build/totem_right/zephyr/zmk.uf2 $(WORKSPACE)/firmware/totem_right.uf2 && chmod 666 $(WORKSPACE)/firmware/totem_right.uf2"
	@echo "Built $(FIRMWARE_DIR)/totem_right.uf2"

flash: all
	@echo ""
	@echo "Flashing instructions:"
	@echo "  1. Plug LEFT half via USB, double-press RESET (enters UF2 bootloader)"
	@echo "  2. Copy firmware/totem_left.uf2 to the mounted XIAO drive"
	@echo "  3. Repeat with RIGHT half and firmware/totem_right.uf2"

clean:
	rm -rf $(FIRMWARE_DIR)

fix-perms:
	@echo "Fixing workspace permissions..."
	-chmod -R a+rwX $(WORKSPACE_DIRS) 2>/dev/null
	@echo "Fixing firmware permissions (via docker, since you don't own the .uf2)..."
	$(DOCKER_RUN) bash -c 'for f in $(WORKSPACE)/$(FIRMWARE_DIR)/*.uf2; do [ -f "$$f" ] || continue; chmod 666 "$$f"; echo "  $$f -> 666"; done'
	@echo "Done."

pristine:
	docker volume rm zmk-build-cache 2>/dev/null || true
	@echo "Build cache wiped. Next make will rebuild from scratch."

nuke: fix-perms
	@echo "Removing west workspace and firmware..."
	rm -rf $(WORKSPACE_DIRS) $(FIRMWARE_DIR)
	docker volume rm zmk-build-cache zmk-zephyr-cache 2>/dev/null || true
	@echo "Full reset done. Run 'make update' then 'make all' to start over."
