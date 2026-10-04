# Sample Boot Image

- **`payload.bin`** (in this folder) — sample HSS-wrapped U-Boot image. Gets you from power-on to a U-Boot prompt. Flash via YMODEM on UART0 — see the main README's [Step 6: Flash `payload.bin`](../README.md#step-6-flash-payloadbin-to-emmc-via-tera-term-ymodem).

- **`sdcard.img`** (full Linux image: kernel + DTB + rootfs) is **not** stored in this repo — it's published as a build artifact on the repo's [**Releases**](https://github.com/nextage-llc/NMC_OS_BSP/releases) page. Download the latest `sdcard.img` from there and flash it via TFTP on UART1 — see the main README's [Step 7: Flash `sdcard.img`](../README.md#step-7-flash-sdcardimg-to-emmc-via-tftp-uart1).

If you'd rather build your own instead of using these, see [Part 1: Build the Images](../README.md#part-1-build-the-images) in the main README.
