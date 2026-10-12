# Sample Boot Images

Pre-built images for each build system. Flash the payload and disk image from the **same** folder — the Buildroot and Yocto U-Boots look for the kernel in different places.

## Buildroot (`buildroot/`)

- **`payload.bin`** (in this folder) — sample HSS-wrapped U-Boot image. Gets you from power-on to a U-Boot prompt. Flash via YMODEM on UART0 — see [Step 6: Flash `payload.bin`](../buildroot/README.md#step-6-flash-payloadbin-to-emmc-via-tera-term-ymodem).

- **`sdcard.img`** (full Linux image: kernel + DTB + rootfs) is **not** stored in this repo — it's published as a build artifact on the repo's [**v2.0.0 Sample Linux NMC**](https://github.com/nextage-llc/NMC_OS_BSP/releases/tag/v2.0.0) release. Download `sdcard.img` from there and flash it via TFTP on UART1 — see [Step 7: Flash `sdcard.img`](../buildroot/README.md#step-7-flash-sdcardimg-to-emmc-via-tftp-uart1).

## Yocto (`yocto/`)

- **`payload-yocto.bin`** (in this folder) — sample HSS-wrapped U-Boot image built with `meta-nmc`. Flash via YMODEM on UART0 — see [Step 9: Flash `payload-yocto.bin`](../yocto/README.md#step-9-flash-payload-yoctobin-to-emmc-via-tera-term-ymodem).

- **`yocto.wic.gz`** (compressed full-disk image, about 138 MB) is **not** stored in this repo — it's published as a build artifact on the repo's [Releases](https://github.com/nextage-llc/NMC_OS_BSP/releases) page. Download `yocto.wic.gz` and flash it via TFTP on UART1 with `gzwrite` — see [Step 10: Flash `yocto.wic.gz`](../yocto/README.md#step-10-flash-yoctowicgz-to-emmc-via-tftp-uart1).

If you'd rather build your own instead of using these, see Part 1 of the [Buildroot](../buildroot/README.md#part-1-build-the-images) or [Yocto](../yocto/README.md#part-1-build-the-images) guide.
