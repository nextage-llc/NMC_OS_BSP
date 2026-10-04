# MPFS NMC RTEMS BSP (`mpfs-nmc-rtems-bsp`)

This repository contains the Board Support Package (BSP) configuration, Device Tree sources, pre-compiled bootloader binaries, and payload generation tools for running **RTEMS** on the Microchip PolarFire SoC (MPFS) NMC platform.

---

## Repository Structure

```text
mpfs-nmc-rtems-bsp/
├── dts/
│   ├── mpfs-nmc-uboot.dts              # Device Tree source file
│   └── mpfs-nmc-board.dtb              # Compiled Device Tree binary
├── hss/
│   ├── hss-envm-wrapper-bm1-p0.bin     # Hart Software Services eNVM wrapper binary
│   └── hss-envm-wrapper-bm1-p0.hex     # Same, in Intel-Hex format (for Libero eNVM programming)
├── sample/
│   ├── ticker                          # Sample RTEMS ELF executable
│   ├── rtems-payload.yaml              # HSS payload configuration file
│   └── payload.bin                     # Output boot image (generated)
└── tools/
    └── hss-payload-generator           # Pre-compiled HSS payload generator tool
```

---

## Before You Begin

- **The board must already be programmed** with the NMC FPGA design and the Hart Software Services (HSS) bootloader in eNVM (`hss/hss-envm-wrapper-bm1-p0.hex`). The HSS provides the UART0 prompt used to flash `payload.bin` below.
- **Host tools:** A Linux host (or WSL2) for building, and Tera Term for the serial terminals.
- **Connections:** USB-to-serial on UART0 and UART1.

## Choose Your Path

- **Use the pre-built sample:** `sample/payload.bin` is already generated from the sample `ticker` application. Skip to [Part 2: Hardware Setup](#part-2-hardware-setup--serial-terminals).
- **Build your own boot image:** Start at [Part 1: Build the Boot Image](#part-1-build-the-boot-image).

---

## Part 1: Build the Boot Image

### Step 1: Install Dependencies

Install all required compilation and Device Tree tools:

```bash
sudo apt update && sudo apt install -y build-essential device-tree-compiler libyaml-dev libelf-dev libssl-dev
```

### Step 2: Compile the Device Tree Binary (`.dtb`) — *only if the `.dts` was modified*

The Device Tree Binary must be recompiled if the Device Tree Source is modified:

```bash
cd mpfs-nmc-rtems-bsp
dtc -I dts -O dtb -o dts/mpfs-nmc-board.dtb dts/mpfs-nmc-uboot.dts
```

### Step 3: Configure Payload Parameters (`rtems-payload.yaml`)

Open `sample/rtems-payload.yaml` and verify that the target executable listed under `payloads:` matches your compiled RTEMS ELF file (`ticker`).

> **Note:** `rtems-payload.yaml` and the `ticker` ELF executable are samples provided for example purposes.

```yaml
# ==============================================================================
# HSS Payload Configuration - RTEMS Application
# ==============================================================================

set-name: 'PolarFire-SoC-HSS::RTEMS'

hart-entry-points: {
  u54_1: '0x1000000000',
  u54_2: '0x1000000000',
  u54_3: '0x1000000000',
  u54_4: '0x1000000000'
}

payloads:
  ticker: {
    exec-addr: '0x1000000000',
    owner-hart: u54_1,
    secondary-hart: u54_2,
    secondary-hart: u54_3,
    secondary-hart: u54_4,
    priv-mode: prv_m,
    skip-opensbi: true
  }
```

### Step 4: Generate the Boot Image (`payload.bin`)

Navigate to the `sample/` directory and execute the bundled payload generator tool located in `../tools/`:

```bash
cd sample
../tools/hss-payload-generator -c rtems-payload.yaml payload.bin
```

> **Note:** Seeing `NOTICE: ticker: ignoring >>exec-addr=0x1000000000<< as payload is an ELF file` is normal. ELF binaries contain embedded entry points, so the tool automatically uses the embedded execution address.

---

## Part 2: Hardware Setup & Serial Terminals

### Step 5: Connect the Board and Open the Serial Terminals

The PolarFire SoC custom board exposes two separate UART interfaces via USB:

- **Primary UART (UART0 / HSS Bootloader):** Displays hardware initialization and boot sequence logs.
- **Secondary UART (UART1 / RTEMS Console):** Displays the active RTEMS application output.

1. Connect the USB cable from the board to your host PC.
2. Open two instances of Tera Term configured for **115200 8N1**:
   - Baud: `115200`
   - Data: `8 bit`
   - Parity: `none`
   - Stop: `1 bit`
   - Flow control: `none`
3. Configure the two Tera Term windows:
   - **Tera Term Window 1:** Connect to the first COM port (HSS Bootloader).
   - **Tera Term Window 2:** Connect to the second COM port (RTEMS Application Console).

---

## Part 3: Flash and Boot

### Step 6: Flash `payload.bin` to eMMC via Tera Term (YMODEM)

**Interrupt the HSS boot sequence:**

1. Power cycle or press the Reset button on the board.
2. Immediately press any key in Tera Term Window 1 to interrupt auto-boot and drop into the HSS prompt (`>>`).

**Launch the MMC utility & receive the image:**

1. Type `YMODEM` at the prompt and press Enter.
2. Type `2` and press Enter to run **MMC Init**.
3. Type `3` and press Enter to select **YMODEM Receive**.

**Transfer the file:**

1. In Tera Term Window 1, navigate to **File → Transfer → YMODEM → Send...**
2. Select `sample/payload.bin` and click **Open**.
3. Wait for the transfer to complete.

**Write the image permanently to flash:**

1. Type `5` and press Enter to run **MMC Write** (writes the image permanently to eMMC flash).
2. Type `6` and press Enter to quit the utility.

### Step 7: Boot the Application

Type `boot` (or power cycle the board). The RTEMS application output appears in Tera Term Window 2.

---

## Additional Resources

- [**NMC2v3 Bring-Up Guide**](../docs/NMC2v3_Bring-Up_Guide_Rev8.pdf) (PDF) — supplementary photo walkthrough covering software installation, cable wiring and connector locations (UART0/UART1 headers, power, FlashPro), and programming the FPGA design and HSS `.hex` into eNVM. The guide's flashing steps target Linux, but the YMODEM `payload.bin` procedure is identical for RTEMS.
