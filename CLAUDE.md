# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A ZMK firmware user config repository for the **Eyelash Sofle** — a wireless split ergonomic keyboard using the nice!nano v2 microcontroller. Firmware is built via GitHub Actions (not locally) using the ZMK build system.

## How Firmware Is Built

There is no local build command. Firmware is compiled by pushing to the `main` branch, which triggers the GitHub Actions workflow at `.github/workflows/build.yml`. The workflow delegates to `zmkfirmware/zmk/.github/workflows/build-user-config.yml@v0.3.0`.

Build targets are defined in `build.yaml`:
- `eyelash_sofle_right` with `nice_view` shield
- `eyelash_sofle_left` with `nice_view` shield + ZMK Studio support (artifact: `eyelash_sofle_studio_left`)
- `nice_nano_v2` with `settings_reset` shield (for clearing settings)

To trigger a build without a code change, use **workflow_dispatch** from the GitHub Actions UI.

## Keymap Diagram Auto-Generation

Pushing changes to `config/**` also triggers `.github/workflows/draw.yml`, which uses [keymap-drawer](https://github.com/caksoylar/keymap-drawer) to auto-generate SVG diagrams into `keymap-drawer/`. The draw workflow commits the updated SVGs back to the repo with a `[Draw]` prefix in the commit message.

## Key Files

| File | Purpose |
|------|---------|
| `config/eyelash_sofle.keymap` | **Primary keymap** — edit this to change key bindings |
| `config/eyelash_sofle.conf` | Kconfig options (RGB, sleep, BLE power, debounce, etc.) |
| `build.yaml` | Defines which board/shield combinations to build |
| `config/west.yml` | West manifest — pins ZMK to `v0.3.0` and pulls the board definition from `https://github.com/a741725193/zmk-sofle` |
| `keymap_drawer.config.yaml` | Visual config for keymap-drawer SVG rendering, including legend mappings |
| `keymap-drawer/eyelash_sofle.svg` | Auto-generated keymap diagram (do not edit manually) |

## Architecture

- **Board definition** lives upstream at `https://github.com/a741725193/zmk-sofle` (referenced in `config/west.yml`), not in this repo. The `boards/arm/eyelash_sofle/` directory in this repo is a copy/reference.
- **Split keyboard**: left half runs ZMK Studio-enabled firmware; right half runs standard firmware. Only the left half needs reflashing to use ZMK Studio.
- **Layers**: 5 layers (0–4). Layer 0 = base QWERTY; Layer 1 = nav/mouse/F-keys (hold `mo 1`); Layer 2 = BT/system/reset (hold `mo 2`); Layers 3–4 are empty placeholders.
- **Encoder**: Left encoder = volume up/down on layer 0, scroll on layers 1–4. The encoder column (col 7/position 6 in bindings) is the encoder position in the binding grid.
- **Soft-off combo**: Holding Q+S+Z (positions 14, 28, 40) for 2 seconds triggers deep sleep (`soft_off`). Wake requires pressing the physical reset button.

## ZMK Keymap Syntax Notes

- Bindings use device-tree syntax: `&kp KEY`, `&mo LAYER`, `&bt BT_SEL N`, `&rgb_ug RGB_*`, `&mmv MOVE_*`, `&msc SCRL_*`, `&mkp BTN`
- `&trans` = transparent (pass-through to lower layer)
- Each layer binding row has 13 keys per half row, split at the middle: left 6 + encoder + right 6, repeated for 5 rows (last row has 12 keys total — no encoder column)
- Mouse support is enabled via `CONFIG_ZMK_POINTING=y` in `.conf`
