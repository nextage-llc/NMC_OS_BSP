# Sample Boot Image

- **`payload.bin`** (in this folder) — sample HSS-wrapped U-Boot image. Gets you from power-on to a U-Boot prompt. Flash via YMODEM on UART0 — see the main README's [Flashing the Image → Step 1](../README.md#step-1-flash-payloadbin-to-emmc-via-tera-term-ymodem).

- **`sdcard.img`** (full Linux image: kernel + DTB + rootfs) is **not** stored in this repo — it's published as a build artifact on the repo's [**Releases**](../../../releases) page. Download the latest `sdcard.img` from there and flash it via TFTP on UART1 — see the main README's [Flashing the Image → Step 2](../README.md#step-2-flash-sdcardimg-to-emmc-via-tftp-uart1).

If you'd rather build your own instead of using these, see [Getting Started](../README.md#getting-started) in the main README.
