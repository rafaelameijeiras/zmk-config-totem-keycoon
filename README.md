# ZMK Config — TOTEM (Keycoon)

[ZMK](https://zmk.dev/) firmware configuration for the **TOTEM** split keyboard from [Keycoon](https://github.com/Keycoon/zmk-config-totem), running on a **XIAO BLE** (nRF52840). Comes with **ZMK Studio** enabled for live keymap editing.

The TOTEM is a 38-key column-staggered split. This repo contains your keymap, the hardware configuration, and the build pipeline. ZMK, Zephyr, and the ARM toolchain are downloaded automatically.

---

## Quick path

### 1. Build with GitHub Actions (recommended to get started)

1. Fork this repo to your account.
2. Edit any file (e.g. a space in `config/totem.keymap`) and commit.
3. Wait for the run to finish in the **Actions** tab.
4. Download the `firmware` artifact from the run page (it's a `.zip`).
5. Unzip it: inside are `totem_left.uf2` and `totem_right.uf2`.

### 2. Build locally with Docker (recommended for iterating)

```bash
make update    # downloads ZMK + Zephyr + modules (once, ~5 min)
make all       # builds both halves
ls firmware/   # your .uf2 files are ready
```

### 3. Flash the firmware

1. Connect the **left half** via USB.
2. Quick double-reset (enters UF2 bootloader; shows up as a `XIAO-SENSE` drive).
3. Drag `totem_left.uf2` onto the drive.
4. Repeat with the **right half** and `totem_right.uf2`.

---

## Repo structure

| Path | What it contains | Do you touch it? |
|---|---|---|
| `config/totem.keymap` | **Your keymap.** Layers, bindings, macros, combos | Yes, always |
| `config/totem.conf` | Kconfig: ZMK Studio, logging, etc. | Sometimes |
| `config/west.yml` | West manifest (where ZMK comes from) | To pin a version |
| `config/boards/shields/totem/` | Hardware definition (key matrix, overlays) | Rarely |
| `build.yaml` | Product matrix for Actions (board + shield + snippet) | To add dongle or another build |
| `.github/workflows/build.yml` | CI trigger | To pin the workflow version |
| `Makefile` | Local build with Docker | Almost never |

---

## The keymap

### Where it lives

All customization goes in [`config/totem.keymap`](config/totem.keymap).

### How it's organized

| Layer | Index | Purpose |
|---|---|---|
| `base` | 0 | Standard QWERTY + thumb modifiers |
| `nav_num` | 1 | Arrows, numbers, navigation |
| `sym_func` | 2 | Symbols, brackets, F-keys |
| `device` | 3 | Media, BT select, brightness |
| `extra1`, `extra2`, `extra3` | 4–6 | **Reserved for ZMK Studio** (empty slots to create layers from the GUI) |

Layer activation: `&mo <index>` for momentary, `&tog <index>` for toggle.

**Conditional layer**: when you're in `nav_num` (1) or `sym_func` (2), `device` (3) activates automatically on a long press. Defined in the `conditional_layers` block at the end of the keymap.

### Mod-tap behavior (at the bottom of the file)

```dts
&mt {
  quick-tap-ms = <100>;
  global-quick-tap;
  flavor = "tap-preferred";
  tapping-term-ms = <170>;
};
```

Tweaks the behavior of mod-tap keys (`&mt`: hold = modifier, tap = regular key).

### How to edit it

- Look up the keycode in [the official ZMK keycodes doc](https://zmk.dev/docs/codes/).
- Replace the binding in the position you want.
- If you add a new layer, place it **before** the `extra*` ones (indices matter).

---

## Building locally without Docker

If you'd rather skip Docker, install the toolchain natively:

1. Install [Zephyr](https://docs.zephyrproject.org/latest/develop/getting_started/index.html) + ARM toolchain + west.
2. From the repo root:

   ```bash
   west init -l config
   west update
   west zephyr-export
   west build -s zmk/app -b xiao_ble -S studio-rpc-usb-uart -d build/left  -- -DSHIELD=totem_left  -DZMK_CONFIG=$PWD/config
   west build -s zmk/app -b xiao_ble -S studio-rpc-usb-uart -d build/right -- -DSHIELD=totem_right -DZMK_CONFIG=$PWD/config
   ```

3. Find the `.uf2` files at `build/left/zephyr/zmk.uf2` and `build/right/zephyr/zmk.uf2`.

---

## ZMK Studio (live keymap editing)

ZMK Studio lets you change layers, bindings, and macros from a GUI without recompiling.

### Already enabled

This repo ships with Studio ready to use:
- `config/totem.conf`: `CONFIG_ZMK_STUDIO=y`
- `build.yaml`: `snippet: studio-rpc-usb-uart`

### How to use it

1. Connect the **left half** via USB (it's the central, the only one that talks to the PC).
2. Open [ZMK Studio](https://zmk.studio/) in your browser.
3. The GUI connects via USB-UART and shows the keymap.
4. Changes save to the keyboard instantly.

### Disabling it (for a lighter firmware)

If you don't use Studio, you can remove it to free up ~30 KB of flash:

1. In `config/totem.conf`, comment out or remove:
   ```
   # CONFIG_ZMK_STUDIO=y
   # CONFIG_ZMK_STUDIO_LOCKING=n
   ```
2. In `build.yaml`, remove `snippet: studio-rpc-usb-uart` from each entry.

---

## Troubleshooting

### Build fails with `Could not find ZephyrConfig.cmake`

You're missing `west zephyr-export`. The Makefile runs it for you, but if you build manually add it:

```bash
west zephyr-export
```

### Build fails with `snippets not found: totem_left`

You're using `-S totem_left`, but `-S` is for **snippet**, not shield. Shields go like this:

```bash
west build ... -- -DSHIELD=totem_left
```

### `make all` fails with `Permission denied` deleting `build/`

Files ended up root-owned because the container runs as root. Fix:

```bash
sudo rm -rf .west zmk zephyr modules bootloader tools build firmware
make update
make all
```

### The `.uf2` ends up root-owned

Expected. For clean ownership:

```bash
sudo chown $USER firmware/*.uf2
```

Or run `make fix-perms`, which tells you exactly which files to fix.

### I want to force a full rebuild

```bash
make pristine   # removes the docker volume with the build cache
make all
```

### I want to reset everything (including west)

```bash
sudo rm -rf .west zmk zephyr modules bootloader tools firmware
docker volume rm zmk-build-cache zmk-zephyr-cache
make update
make all
```

---

## Customization

### Add a new layer

1. In `config/totem.keymap`, add a block before the `extra*` ones:

   ```dts
   my_layer {
       display-name = "My Layer";
       bindings = <
           &kp A  &kp B  &kp C  ...
       >;
   };
   ```

2. It gets an implicit index based on its order in the file.
3. Add an `&mo <index>` or `&tog <index>` somewhere to activate it.

### Pin the ZMK version

By default, `config/west.yml` points to ZMK `main` (rolling release). For stability:

```yaml
projects:
  - name: zmk
    remote: zmkfirmware
    revision: v0.5  # or whichever tag you want
    import: app/west.yml
```

And in `.github/workflows/build.yml`:

```yaml
uses: zmkfirmware/zmk/.github/workflows/build-user-config.yml@v0.5
```

### Add a dongle (experimental)

If you later want a XIAO BLE dongle, add it to `build.yaml`:

```yaml
include:
  - board: xiao_ble//zmk
    shield: totem_left
    snippet: studio-rpc-usb-uart
  - board: xiao_ble//zmk
    shield: totem_right
  - board: xiao_ble//zmk
    shield: totem_dongle   # requires the manufacturer to provide this shield
```

---

## Make targets (quick reference)

| Command | What it does |
|---|---|
| `make` / `make all` | Builds left + right |
| `make left` / `make right` | One half only |
| `make update` | Initializes/updates the west workspace |
| `make clean` | Removes `firmware/` |
| `make pristine` | Removes the build cache (full rebuild) |
| `make flash` | Prints flashing instructions |
| `make fix-perms` | Tells you which `.uf2` files are root-owned |
| `make help` | Lists all targets |

---

## Resources

- [ZMK Docs](https://zmk.dev/docs/)
- [ZMK Keycodes](https://zmk.dev/docs/codes/)
- [ZMK Studio](https://zmk.studio/)
- [TOTEM hardware (Keycoon)](https://github.com/Keycoon)
- [TOTEM hardware (original GEIGEIGEIST)](https://github.com/GEIGEIGEIST/TOTEM)
- [ZMK Discord](https://zmk.dev/community/discord/invite) — support channel
