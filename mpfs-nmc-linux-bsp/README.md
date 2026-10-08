# MPFS NMC Linux BSP (`mpfs-nmc-linux-bsp`)

This repository contains the Board Support Package (BSP) configuration, Device Tree sources, Buildroot/U-Boot/Linux configuration, and a sample boot image for running **Linux** (via Buildroot) on the Microchip PolarFire SoC (MPFS) NMC platform.

---

## Repository Structure

```text
mpfs-nmc-linux-bsp/
├── uboot/
│   ├── .config                 # U-Boot configuration
│   └── mpfs-nmc-uboot.dts      # U-Boot device tree source
├── linux/
│   ├── .config                 # Linux kernel configuration
│   └── mpfs-nmc-linux.dts      # Linux device tree source
├── buildroot/
│   └── .config                 # Buildroot configuration
└── sample/
    ├── payload.bin             # Sample HSS-wrapped U-Boot image
    └── README.md               # Link to the full sample Linux image (GitHub Release)
```

---

## Before You Begin

- **The board must already be programmed** with the NMC FPGA design and the Hart Software Services (HSS) bootloader in eNVM. The HSS provides the UART0 prompt used to flash `payload.bin` below.
- **Host tools:** WSL2 / Ubuntu 22.04 LTS (for building), Tera Term (serial terminals), and a TFTP server such as tftpd64.
- **Connections:** USB-to-serial on UART0 and UART1, and an Ethernet cable from the board to the host PC.

## Choose Your Path

Two images are flashed to the board: **`payload.bin`** (HSS-wrapped U-Boot) and **`sdcard.img`** (kernel + DTB + rootfs).

- **Use the pre-built images:** `sample/payload.bin` in this repo is ready to flash as-is, and a pre-built `sdcard.img` is available on the [v2.0.0 Sample Linux NMC](https://github.com/nextage-llc/NMC_OS_BSP/releases/tag/v2.0.0) release page. Skip to [Part 2: Hardware Setup](#part-2-hardware-setup--serial-terminals).
- **Build from source:** Start at [Part 1: Build the Images](#part-1-build-the-images).

---

## Part 1: Build the Images

### Step 1: Install Dependencies

Install Buildroot's required host dependencies (tested on WSL2 / Ubuntu 22.04 LTS):

```bash
sudo apt-get install subversion build-essential bison flex gettext \
  libncurses5-dev texinfo autoconf automake libtool mercurial git-core \
  gperf gawk expat curl cvs libexpat-dev bzr unzip bc python3-dev \
  wget cpio rsync xxd bmap-tools libgnutls28-dev libgl1
```

> **Note:** Do all cloning/building inside the Linux filesystem (e.g. `~/NMC-Linux`), not under `/mnt/c/...` - building on the Windows-mounted filesystem in WSL2 is dramatically slower and can cause path issues.

### Step 2: Set Up Your Workspace

```bash
mkdir -p ~/NMC-Linux && cd ~/NMC-Linux

git clone https://github.com/linux4microchip/buildroot-external-microchip.git
git clone https://git.busybox.net/buildroot -b 2025.02.11
```

Then add this BSP to the same workspace. If you have it as a `.zip`, extract it on Windows and copy it into WSL so it sits alongside `buildroot/` and `buildroot-external-microchip/`:

```bash
cp -r /mnt/c/Users/<you>/Downloads/mpfs-nmc-linux-bsp ~/NMC-Linux/
```

> Your Windows drive is mounted under `/mnt/c/` in WSL2. Adjust the path above to wherever you extracted the zip. If you already copied the `.zip` itself into WSL, `unzip mpfs-nmc-linux-bsp.zip -d ~/NMC-Linux/` works too.
>
> Ensure none of your shell environment variables contain stray spaces, tabs, or newlines (Buildroot is picky about this).

### Step 3: Build the Baseline Icicle Kit Image

The NMC board uses the same MPFS250T chip as Microchip's Icicle Kit, so `icicle_defconfig` is the correct starting point:

```bash
cd ~/NMC-Linux/buildroot
BR2_EXTERNAL=../buildroot-external-microchip/ make icicle_defconfig
make
```

> **Note:** Initial build takes ~1 hour. Subsequent builds are typically under a minute.

### Step 4: Apply the NMC Board Overlay

Copy this repo's configs and DTS files into the Buildroot output tree, then rebuild. Run all commands from `~/NMC-Linux/buildroot`:

> **Note:** `output/build/uboot-custom/` and `output/build/linux-custom/` are only created once Step 3 has completed - run this step after that build finishes, or the `cp` commands below will fail.

```bash
# Apply configs - each keeps its native filename
cp ~/NMC-Linux/mpfs-nmc-linux-bsp/buildroot/.config .config
cp ~/NMC-Linux/mpfs-nmc-linux-bsp/uboot/.config output/build/uboot-custom/.config
cp ~/NMC-Linux/mpfs-nmc-linux-bsp/linux/.config output/build/linux-custom/.config

# Overwrite DTS files in the build trees
cp ~/NMC-Linux/mpfs-nmc-linux-bsp/uboot/mpfs-nmc-uboot.dts \
   output/build/uboot-custom/dts/upstream/src/riscv/microchip/mpfs-icicle-kit.dts
cp ~/NMC-Linux/mpfs-nmc-linux-bsp/linux/mpfs-nmc-linux.dts \
   output/build/linux-custom/arch/riscv/boot/dts/microchip/mpfs-icicle-kit.dts
cp ~/NMC-Linux/mpfs-nmc-linux-bsp/linux/mpfs-nmc-linux.dts \
   output/build/linux-custom/arch/riscv/boot/dts/microchip/mpfs-icicle-kit-prod.dts

# Touch main.c so the kernel build timestamp updates
touch output/build/linux-custom/init/main.c

# Delete cached output artifacts
rm -f output/images/payload.bin output/images/mpfs_icicle.itb \
      output/images/boot.vfat output/images/sdcard.img

# Rebuild U-Boot, kernel, HSS payload generator, and final image
make uboot-rebuild
make linux-rebuild
make host-hss-payload-generator-rebuild
make
```

> **Note:** Outputs land in `buildroot/output/images/` — `payload.bin`, `sdcard.img`, `mpfs_icicle.itb`, and `boot.vfat`. To adjust peripherals/config instead of applying a saved snapshot, use `make menuconfig`, `make uboot-menuconfig`, or `make linux-menuconfig`.

---

## Part 2: Hardware Setup & Serial Terminals

### Step 5: Connect the Board and Open the Serial Terminals

The PolarFire SoC custom board exposes two separate UART interfaces via USB:

- **Primary UART (UART0 / HSS Bootloader):** Displays hardware initialization and boot sequence logs.
- **Secondary UART (UART1 / U-Boot & Linux Console):** Displays U-Boot commands and the Linux console once booted.

1. Connect the USB cable from the board to your host PC.
2. Open two instances of Tera Term configured for **115200 8N1**:
   - Baud: `115200`
   - Data: `8 bit`
   - Parity: `none`
   - Stop: `1 bit`
   - Flow control: `none`
3. Configure the two Tera Term windows:
   - **Tera Term Window 1:** Connect to the first COM port (HSS Bootloader).
   - **Tera Term Window 2:** Connect to the second COM port (U-Boot / Linux Console).

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
2. Select your `payload.bin` (`buildroot/output/images/payload.bin`, or `sample/payload.bin`) and click **Open**.
3. Wait for the transfer to complete.

**Write the image permanently to flash:**

1. Type `5` and press Enter to run **MMC Write** (writes the image permanently to eMMC flash).
2. Type `6` and press Enter to quit the utility.

> **Checkpoint:** Resetting the board should now land at a U-Boot prompt in Tera Term Window 2. Resolve this before continuing to Step 7.

### Step 7: Flash `sdcard.img` to eMMC via TFTP (UART1)

**Set up the TFTP server:**

1. Connect the board's Ethernet port to your host PC.
2. Start a TFTP server (e.g. **tftpd64**), point it at the directory containing your `sdcard.img` (`buildroot/output/images/sdcard.img`, or the one downloaded from the [v2.0.0 Sample Linux NMC](https://github.com/nextage-llc/NMC_OS_BSP/releases/tag/v2.0.0) release), and select your host's Ethernet interface.

**Configure the network in Tera Term Window 2:**

```text
setenv ipaddr 169.254.69.99
setenv serverip 169.254.69.98
```

> Adjust `serverip` to match your host's Ethernet interface, and `ipaddr` to an unused address on the same subnet.

**Load and write the image:**

```text
tftpboot 0x84000000 sdcard.img
setexpr blkcnt ${filesize} + 0x1ff
setexpr blkcnt ${blkcnt} / 0x200
mmc dev 0
mmc write 0x84000000 0 ${blkcnt}
```

### Step 8: Boot Linux from eMMC

```text
fatload mmc 0:2 0x84000000 mpfs_icicle.itb
bootm 0x84000000
```

Or type `boot` (or power cycle the board) once U-Boot is configured to load from eMMC by default.
(see [Known Issues](#known-issues)).

---

## Post-Boot Notes

### Login

```text
login: root
password: root
```

---

## Known Issues

### Reset lands at the U-Boot prompt instead of booting Linux

If a reset lands back at the U-Boot prompt instead of booting Linux automatically, `bootcmd` hasn't been persisted yet:

```text
printenv bootcmd
# bootcmd=fatload mmc 0:2 0x84000000 mpfs_icicle.itb; bootm 0x84000000
```

If it already matches the command above, run:

```text
saveenv
```

Resets will boot straight into Linux from then on.

### U-Boot or kernel `.config` reverts to Icicle Kit defaults

Buildroot generates `output/build/uboot-custom/.config` and `output/build/linux-custom/.config` itself (Icicle defconfig + `buildroot-external-microchip` fragment), and will regenerate them — overwriting the files copied in Step 4 — when:

- `make uboot-reconfigure` or `make linux-reconfigure` is run
- `make clean`, `make uboot-dirclean`, or `make linux-dirclean` is run (this also removes the copied DTS files)
- files in `buildroot-external-microchip` change (e.g. after a `git pull`)
- the WSL2 clock is out of sync (`make` prints `Clock skew detected`); run `wsl --shutdown` from Windows and reopen WSL to resync

**Check** after Step 4's build finishes (run from `~/NMC-Linux/buildroot`):

```bash
diff -q ~/NMC-Linux/mpfs-nmc-linux-bsp/uboot/.config output/build/uboot-custom/.config || echo "U-BOOT CONFIG DIFFERS"
diff -q ~/NMC-Linux/mpfs-nmc-linux-bsp/linux/.config output/build/linux-custom/.config || echo "LINUX CONFIG DIFFERS"
```

**Fix:** repeat Step 4. The regeneration that overwrote the files also refreshes Buildroot's internal timestamp, so the second copy sticks (if the WSL2 clock was the cause, resync it first). Avoid running `uboot-reconfigure` / `linux-reconfigure` after Step 4.

---

## Additional Resources

- [**NMC2v3 Bring-Up Guide**](../docs/NMC2v3_Bring-Up_Guide_Rev8.pdf) (PDF) — supplementary photo walkthrough of this process, including software installation, cable wiring and connector locations (UART0/UART1 headers, Ethernet, power, FlashPro), and programming the FPGA design and HSS into eNVM.
