# NMC Linux via Yocto

Build and boot **Linux** on the Microchip PolarFire SoC (MPFS) NMC platform using Yocto/OpenEmbedded and Microchip's [`meta-mchp`](https://github.com/linux4microchip/meta-mchp) BSP (Yocto release scarthgap). The NMC changes are packaged as a Yocto layer, [`meta-nmc`](./meta-nmc), which you add to the build instead of copying files into the build tree. For the BSP layout and the Buildroot alternative, see the [Linux BSP README](../README.md).

---

## What `meta-nmc` Does

The NMC uses the same MPFS250T chip as the Icicle Kit, so the build keeps `MACHINE=mpfs-icicle-kit` and `meta-nmc` overwrites the Icicle Kit device trees with the NMC ones. Do not create a custom machine, because Microchip's recipes look up files by machine name.

```text
meta-nmc/
├── conf/layer.conf                         # Sets NMC_BSP_DIR = <bsp root>
├── recipes-kernel/linux/
│   └── linux-mchp_%.bbappend               # ../linux/mpfs-nmc-linux.dts → mpfs-icicle-kit{,-prod}.dts
└── recipes-bsp/u-boot/
    ├── u-boot-mchp_%.bbappend              # ../uboot/mpfs-nmc-uboot.dts → mpfs-icicle-kit.dts
    └── files/nmc-uboot.cfg                 # U-Boot GPIO/gpio-hog options (Ethernet PHY reset)
```

- **Device trees are shared with Buildroot.** The bbappends read `mpfs-nmc-linux.dts` and `mpfs-nmc-uboot.dts` straight from this BSP's `linux/` and `uboot/` folders, so keep `meta-nmc` inside the BSP (at `<bsp>/yocto/meta-nmc`) rather than copying it out on its own.
- **U-Boot options come from a fragment.** The NMC U-Boot device tree releases both Ethernet PHYs from reset with `gpio-hog` nodes on `gpio2`. Microchip's stock U-Boot configuration does not include the GPIO driver or hog support, so without `nmc-uboot.cfg` U-Boot ignores those nodes, the PHYs stay in reset, and TFTP fails with `PHY not found`.
- **Kernel options are not applied yet.** Yocto builds the kernel from Microchip's default configuration. The NMC kernel options from `linux/.config` still need to be added as `.cfg` fragments (see [Known Issues](#nmc-kernel-config-options-are-not-applied)).
- **The `%` in the bbappend filenames** matches any recipe version, so the files keep working when Microchip updates `linux-mchp` or `u-boot-mchp`.

---

## Before You Begin

- **The board must already be programmed** with the NMC FPGA design and the Hart Software Services (HSS) bootloader in eNVM. The HSS provides the UART0 prompt used to flash `payload-yocto.bin` below.
- **Host tools:** WSL2 / Ubuntu 22.04 LTS (for building), Tera Term (serial terminals), and a TFTP server such as tftpd64.
- **Host resources:** roughly 100 GB of free disk and 16 GB of RAM or more. The first build takes several hours.
- **Connections:** USB-to-serial on UART0 and UART1, and an Ethernet cable from the board's J19 connector (eth0) to the host PC.

## Choose Your Path

Two images are flashed to the board: **`payload-yocto.bin`** (HSS-wrapped U-Boot) and **`yocto.wic.gz`** (compressed full-disk image: boot partition with `fitImage` + `boot.scr`, and the rootfs).

- **Use the pre-built images:** `sample/yocto/payload-yocto.bin` in this BSP is ready to flash as-is, and a pre-built `yocto.wic.gz` is available on the [v2.0.0 Sample Linux NMC](https://github.com/nextage-llc/NMC_OS_BSP/releases/tag/v2.0.0) release page. Skip to [Part 2: Hardware Setup](#part-2-hardware-setup--serial-terminals).
- **Build from source:** Start at [Part 1: Build the Images](#part-1-build-the-images).

> Flash the payload and disk image from the same build system. The Yocto U-Boot boots `fitImage` from partition 1 via `boot.scr`, while the Buildroot U-Boot boots `mpfs_icicle.itb` from partition 2, so a mixed pair will not boot on its own.

---

## Part 1: Build the Images

> **Note:** Do all cloning/building inside the WSL2 Linux filesystem (e.g. `~/nmc-yocto`), not under `/mnt/c/...` - building on the Windows-mounted filesystem is dramatically slower and can cause path issues.

### Step 1: Install Dependencies

```bash
sudo apt update
sudo apt-get install gawk wget git git-lfs diffstat unzip texinfo gcc \
  build-essential chrpath socat cpio python3 python3-pip \
  python3-pexpect xz-utils debianutils iputils-ping python3-git \
  python3-jinja2 python3-subunit zstd lz4 file locales \
  libacl1 libgl1 repo bmap-tools
sudo locale-gen en_US.UTF-8
```

### Step 2: Fetch the Microchip Yocto BSP

Set your git identity once, since `repo init` asks for it:

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git lfs install
```

```bash
mkdir -p ~/nmc-yocto && cd ~/nmc-yocto
repo init -u https://github.com/linux4microchip/meta-mchp-manifest.git \
  -b refs/tags/linux4microchip-2026.04 -m polarfire-soc/default.xml
repo sync
```

> **Note:** Stay on `linux4microchip-2026.04` unless you also update this BSP. Its `linux/` and `uboot/` sources were taken from that release (kernel `6.18.17-linux4microchip-2026.04.1`, U-Boot `2025.07-linux4microchip-2026.04`). A newer tag may need device tree changes. Do not use the older `meta-polarfire-soc-yocto-bsp` repo; it was archived in April 2026.

Then add this BSP to the same workspace. Copy it from Windows into WSL so it sits alongside the `repo` checkout:

```bash
cp -r /mnt/c/Users/<you>/Downloads/mpfs-nmc-linux-bsp ~/nmc-yocto/
```

> Your Windows drive is mounted under `/mnt/c/` in WSL2. Adjust the path above to wherever you extracted the BSP. If you edit the device trees on Windows later, copy them in again before rebuilding.

### Step 3: Initialize the Build Environment

```bash
cd ~/nmc-yocto
export TEMPLATECONF=${TEMPLATECONF:-../meta-mchp/meta-mchp-polarfire-soc/meta-mchp-polarfire-soc-bsp/conf/templates/default}
source openembedded-core/oe-init-build-env
```

> `TEMPLATECONF` is only needed the first time. In every new shell, run `source openembedded-core/oe-init-build-env` again from `~/nmc-yocto` before using `bitbake`.

### Step 4: Build the Baseline Icicle Kit Image

```bash
MACHINE=mpfs-icicle-kit bitbake mchp-base-image
```

Outputs land in `build/tmp-glibc/deploy/images/mpfs-icicle-kit/`: the `.wic.gz` disk image and the HSS `payload.bin`. If `payload.bin` is missing, find the HSS payload recipe with `bitbake-layers show-recipes "*hss*"` and build it.

> **Note:** Building the baseline first is optional, but it confirms the host setup works before the NMC layer is involved, and it creates the build tree used by the checks in Step 6.

### Step 5: Add the NMC Layer

```bash
cd ~/nmc-yocto/build
bitbake-layers add-layer ~/nmc-yocto/mpfs-nmc-linux-bsp/yocto/meta-nmc
bitbake-layers show-layers | grep nmc
```

Check that BitBake picked up the NMC files:

```bash
bitbake -e virtual/kernel | grep ^SRC_URI=
bitbake -e virtual/bootloader | grep ^SRC_URI=
```

The kernel line should end with `file://mpfs-nmc-linux.dts`, and the U-Boot line should end with `file://mpfs-nmc-uboot.dts file://nmc-uboot.cfg`. If either is missing, the layer is not added or a filename is wrong.

Check that the U-Boot options were applied. Force the configure step and look for the four options (a `tainted from a forced run` warning is expected):

```bash
MACHINE=mpfs-icicle-kit bitbake -f -c configure u-boot-mchp
YCFG=$(find ~/nmc-yocto/build/tmp-glibc/work/mpfs_icicle_kit-mchp-linux/u-boot-mchp -name .config | head -1)
grep -E 'CONFIG_(DM_GPIO|CMD_GPIO|GPIO_HOG|MPFS_GPIO)[ =]' $YCFG
```

All four should show `=y`. If any show `# ... is not set`, the fragment was not merged.

### Step 6: Rebuild with the NMC Layer

This is much faster than the first build, because only the kernel, U-Boot, the HSS payload and the image are rebuilt:

```bash
cd ~/nmc-yocto/build
MACHINE=mpfs-icicle-kit bitbake mchp-base-image
```

When it finishes, look for `There were 0 ERROR messages`, and check that the newest files in the deploy folder have today's date:

```bash
ls -lt ~/nmc-yocto/build/tmp-glibc/deploy/images/mpfs-icicle-kit | head
```

Confirm the NMC device trees were applied by comparing them with the copies in the build trees. No output means they are identical:

```bash
cd ~/nmc-yocto
W=build/tmp-glibc/work/mpfs_icicle_kit-mchp-linux
diff -q mpfs-nmc-linux-bsp/linux/mpfs-nmc-linux.dts \
  $W/linux-mchp/*/git/arch/riscv/boot/dts/microchip/mpfs-icicle-kit.dts
diff -q mpfs-nmc-linux-bsp/uboot/mpfs-nmc-uboot.dts \
  $W/u-boot-mchp/*/git/dts/upstream/src/riscv/microchip/mpfs-icicle-kit.dts
```

If the build stops with `do_package` errors mentioning `Bad address`, see [Known Issues](#do_package-fails-with-bad-address).

### Step 7: Copy the Images to Windows

The TFTP server and Tera Term run on Windows, so copy the two images out of the WSL build folder (e.g. to `C:\nmc-images`). Copy rather than browse to them over `\\wsl$`, because the deploy-folder names are symlinks:

```bash
mkdir -p /mnt/c/nmc-images
cd ~/nmc-yocto/build/tmp-glibc/deploy/images/mpfs-icicle-kit
cp payload.bin /mnt/c/nmc-images/payload-yocto.bin
cp mchp-base-image-mpfs-icicle-kit.rootfs.wic.gz /mnt/c/nmc-images/yocto.wic.gz
```

> The `-yocto` names keep these from being confused with the Buildroot `payload.bin`. Send the compressed `.wic.gz` (about 138 MB): the uncompressed `.wic` (about 715 MB) does not fit in U-Boot's RAM. To refresh the BSP's sample images with a new build, copy them into `mpfs-nmc-linux-bsp/sample/yocto/` instead.

---

## Part 2: Hardware Setup & Serial Terminals

### Step 8: Connect the Board and Open the Serial Terminals

The PolarFire SoC custom board exposes two separate UART interfaces via USB:

- **Primary UART (UART0 / HSS Bootloader):** Displays hardware initialization and boot sequence logs.
- **Secondary UART (UART1 / U-Boot & Linux Console):** Displays DDR training, the OpenSBI banner, U-Boot, and the Linux console once booted.

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

### Step 9: Flash `payload-yocto.bin` to eMMC via Tera Term (YMODEM)

**Interrupt the HSS boot sequence:**

1. Power cycle or press the Reset button on the board.
2. Immediately press any key in Tera Term Window 1 to interrupt auto-boot and drop into the HSS prompt (`>>`).

**Launch the MMC utility & receive the image:**

1. Type `YMODEM` at the prompt and press Enter.
2. Type `2` and press Enter to run **MMC Init**.
3. Type `3` and press Enter to select **YMODEM Receive**.

**Transfer the file:**

1. In Tera Term Window 1, navigate to **File → Transfer → YMODEM → Send...**
2. Select your `payload-yocto.bin` (`C:\nmc-images\payload-yocto.bin`, or `sample/yocto/payload-yocto.bin`) and click **Open**.
3. Wait for the transfer to complete.

**Write the image permanently to flash:**

1. Type `5` and press Enter to run **MMC Write** (writes the image permanently to eMMC flash).
2. Type `6` and press Enter to quit the utility.

> **Checkpoint:** Resetting the board should now land at a U-Boot prompt in Tera Term Window 2. Resolve this before continuing to Step 10.

### Step 10: Flash `yocto.wic.gz` to eMMC via TFTP (UART1)

**Set up the TFTP server:**

1. Connect the board's J19 Ethernet port (eth0 end of the cable) to your host PC.
2. Start a TFTP server (e.g. **tftpd64**), point it at the folder containing `yocto.wic.gz` (your own build, or the one downloaded from the [v2.0.0 Sample Linux NMC](https://github.com/nextage-llc/NMC_OS_BSP/releases/tag/v2.0.0) release), and select your host's Ethernet interface. Note the interface's IP address; set it manually on the host adapter if needed.

**Configure the network in Tera Term Window 2:**

```text
setenv serverip 169.254.69.98
setenv ipaddr 169.254.69.99
```

> Set `serverip` to your host's Ethernet interface address, and `ipaddr` to an unused address on the same subnet.

**Load and write the image:**

`gzwrite` decompresses while it writes, so the compressed image is all that has to fit in RAM. Check that the command exists first with `help gzwrite`.

```text
tftpboot 0x84000000 yocto.wic.gz
mmc dev 0
gzwrite mmc 0 0x84000000 ${filesize}
```

`gzwrite` prints the number of bytes written (715,377,664 in our build) and a CRC. Check the result:

```text
part list mmc 0
ls mmc 0:1
```

`part list` should show three partitions named `boot`, `primary` and `root`, and `ls` should list `boot.scr`, `fitImage` and `uboot.env`.

### Step 11: Boot Linux from eMMC

Reset the board. The Yocto image boots Linux by itself: U-Boot runs `boot.scr` from the boot partition, so there is no `bootcmd` to save. If it stops at the U-Boot prompt, boot manually:

```text
fatload mmc 0:1 0x84000000 fitImage
bootm 0x84000000
```

---

## Post-Boot Notes

### Login

```text
login: root
password: (none)
```

### Disabling Ethernet to Save Power (Optional)

The Ethernet PHYs keep drawing power even with no cable connected. Taking the Linux interfaces down powers the PHYs down, which dramatically reduced the NMC's power draw in testing. TFTP reflashing (Step 10) is unaffected, because it runs in U-Boot with its own network stack. With Ethernet off, UART1 is the way into the board.

U-Boot calls the interfaces `eth0`/`eth1`; Linux names them `end0`/`end1`. Check with `ip -br link`.

**Until the next reboot:**

```bash
ip link set end0 down
ip link set end1 down
ip -br link          # both should show DOWN
```

Bring them back with `ip link set end0 up` / `ip link set end1 up`, then re-add any static IP or restart your DHCP client.

**Across reboots**, create a systemd service (run `which ip` first and use that path if it is not `/sbin/ip`):

```bash
cat > /etc/systemd/system/eth-down.service << 'EOF'
[Unit]
Description=Bring Ethernet down to save power
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/ip link set end0 down
ExecStart=/sbin/ip link set end1 down

[Install]
WantedBy=multi-user.target
EOF
systemctl enable eth-down.service
```

Reflashing replaces the root filesystem, so this service has to be re-created after each reflash unless it is added to `meta-nmc`.

---

## Known Issues

### NMC kernel config options are not applied

`meta-nmc` replaces the device trees and adds the U-Boot GPIO options, but the kernel is still built from Microchip's default configuration, not from `linux/.config`. In Yocto, kernel options are added as small `.cfg` fragments on top of the default configuration rather than as a complete `.config`. Microchip also builds device tree overlays for this machine that assume Icicle Kit nodes, so check the boot log for overlay errors.

### `do_package` fails with `Bad address`

If a rebuild stops with `do_package` errors that include `got *at() syscall for unknown directory` and `tar: ... Cannot open: Bad address`, the host `tar` is failing under Yocto's fake-root tool (seen after Ubuntu 22.04 updated `tar` to `1.34+dfsg-1ubuntu0.1.22.04.6`). Use the `tar` from Yocto's prebuilt host tools instead:

```bash
cd ~/nmc-yocto
./openembedded-core/scripts/install-buildtools
source ~/nmc-yocto/openembedded-core/buildtools/environment-setup-x86_64-pokysdk-linux
source openembedded-core/oe-init-build-env
rm -rf ~/nmc-yocto/build/tmp-glibc/hosttools
tar --version | head -1     # should report tar 1.35
```

Deleting `hosttools` is needed because BitBake keeps links to the host programs it found on an earlier run. After rebuilding, `ls -l ~/nmc-yocto/build/tmp-glibc/hosttools/tar` should point into the `buildtools` folder. In every new shell, run both `source` lines, buildtools first, before using `bitbake`.

### `tftpboot` fails with `trying to overwrite reserved memory`

The uncompressed `.wic` (about 715 MB) does not fit in U-Boot's RAM at the load address. Send `yocto.wic.gz` and write it with `gzwrite` as in Step 10.

---

## Additional Resources

- [**NMC2v3 Bring-Up Guide (Yocto)**](../../docs/NMC2v3_Bring-Up_Guide_Rev16_Yocto.pdf) (PDF) — supplementary photo walkthrough of this process, including software installation, cable wiring and connector locations (UART0/UART1 headers, Ethernet, power, FlashPro), and programming the FPGA design and HSS into eNVM. The guide creates `meta-nmc` by hand; this BSP ships it ready to add (Step 5).
