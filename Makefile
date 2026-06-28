DOCKER_IMAGE ?= zmkfirmware/zmk-build-arm:stable
WORKSPACE := /workspace
DOCKER_VOLUMES := -v zmk-zephyr-cache:/root/.cache/zephyr -v zmk-build-cache:/tmp/build

DOCKER_RUN := docker run --rm \
	-v "$(CURDIR)":$(WORKSPACE) \
	-w $(WORKSPACE) \
	$(DOCKER_VOLUMES) \
	$(DOCKER_IMAGE)

BOARD := xiao_ble
SNIPPET := studio-rpc-usb-uart
FIRMWARE_DIR := firmware

.PHONY: all update left right clean pristine flash help fix-perms

help:
	@echo "Targets:"
	@echo "  all       - build left and right (default)"
	@echo "  left      - build totem_left only"
	@echo "  right     - build totem_right only"
	@echo "  update    - initialize or update west workspace (ZMK, Zephyr, modules)"
	@echo "  flash     - print instructions to flash the .uf2 files"
	@echo "  clean     - remove firmware/ directory"
	@echo "  pristine  - wipe docker build cache (forces full rebuild)"
	@echo "  fix-perms - chown firmware/*.uf2 to current user (run with sudo if needed)"
	@echo "  nuke      - wipe west workspace + docker caches (full reset)"

all: left right

update:
	$(DOCKER_RUN) bash -c "[ -d .west ] || west init -l config; west update; west zephyr-export"

$(FIRMWARE_DIR)/totem_left.uf2:
	@mkdir -p $(FIRMWARE_DIR)
	$(DOCKER_RUN) bash -c "[ -d .west ] || west init -l config; west zephyr-export; west build -s zmk/app -b $(BOARD) -S $(SNIPPET) -d /tmp/build/totem_left -- -DSHIELD=totem_left -DZMK_CONFIG=$(WORKSPACE)/config && cp /tmp/build/totem_left/zephyr/zmk.uf2 $(WORKSPACE)/firmware/totem_left.uf2"
	@echo "Built $(FIRMWARE_DIR)/totem_left.uf2"

$(FIRMWARE_DIR)/totem_right.uf2:
	@mkdir -p $(FIRMWARE_DIR)
	$(DOCKER_RUN) bash -c "[ -d .west ] || west init -l config; west zephyr-export; west build -s zmk/app -b $(BOARD) -S $(SNIPPET) -d /tmp/build/totem_right -- -DSHIELD=totem_right -DZMK_CONFIG=$(WORKSPACE)/config && cp /tmp/build/totem_right/zephyr/zmk.uf2 $(WORKSPACE)/firmware/totem_right.uf2"
	@echo "Built $(FIRMWARE_DIR)/totem_right.uf2"

left: $(FIRMWARE_DIR)/totem_left.uf2
right: $(FIRMWARE_DIR)/totem_right.uf2

flash: all
	@echo ""
	@echo "Flashing instructions:"
	@echo "  1. Plug LEFT half via USB, double-press RESET (enters UF2 bootloader)"
	@echo "  2. Copy firmware/totem_left.uf2 to the mounted XIAO drive"
	@echo "  3. Repeat with RIGHT half and firmware/totem_right.uf2"

clean:
	rm -rf $(FIRMWARE_DIR)

fix-perms:
	@for f in $(FIRMWARE_DIR)/*.uf2; do \
		[ -f "$$f" ] || continue; \
		if [ "$$(stat -c %U $$f)" != "$$(whoami)" ]; then \
			echo "$$f is owned by $$(stat -c %U $$f). Run: sudo chown \$$USER $$f"; \
		fi; \
	done

pristine:
	docker volume rm zmk-build-cache 2>/dev/null || true
	@echo "Build cache wiped. Next make will rebuild from scratch."

nuke:
	@echo "This will delete .west/ zmk/ zephyr/ modules/ bootloader/ tools/ firmware/"
	@echo "Run with sudo if you get permission errors:"
	@echo "  sudo rm -rf .west zmk zephyr modules bootloader tools firmware"
	@echo "  docker volume rm zmk-build-cache zmk-zephyr-cache"
