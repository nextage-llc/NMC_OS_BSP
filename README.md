# MPFS NMC OS Boot Workspace (`MPFS_NMC_OS`)

This repository contains the bootloader, Board Support Packages (BSPs), and tools for booting an operating system on the Microchip PolarFire SoC (MPFS) NMC platform.

The NMC board supports two boot targets — **RTEMS** and **Linux**. Each target has its own BSP with a complete, standalone set of instructions.

---

## Start Here

| I want to...                                      | Go to                                                                  |
| ------------------------------------------------- | ---------------------------------------------------------------------- |
| Build and boot **Linux** on the NMC board         | [`mpfs-nmc-linux-bsp/README.md`](./mpfs-nmc-linux-bsp/README.md)       |
| Build and boot **RTEMS** on the NMC board         | [`mpfs-nmc-rtems-bsp/README.md`](./mpfs-nmc-rtems-bsp/README.md)       |
| Rebuild the HSS bootloader or BSP tools           | [Maintainer Guide](#maintainer-guide) (below)                          |

---

## How the Board Boots

Both boot targets share the same first-stage bootloader:

```text
eNVM:  Hart Software Services (HSS)
         │
         ▼  loads payload.bin from eMMC
eMMC:  payload.bin
         ├── RTEMS:  RTEMS application
         └── Linux:  U-Boot ──► Linux kernel + rootfs (sdcard.img)
```

The HSS is common to both targets — choosing RTEMS or Linux comes down to which `payload.bin` (and, for Linux, `sdcard.img`) is flashed to eMMC.

---

## Directory Structure

```text
MPFS_NMC_OS/
├── docs/                       # Supplementary documentation (NMC Bring-Up Guide)
├── hart-software-services/     # Microchip HSS source code repository
├── mpfs-nmc-rtems-bsp/         # Distributed RTEMS Board Support Package
└── mpfs-nmc-linux-bsp/         # Distributed Linux (Buildroot) Board Support Package
```

---

## Additional Resources

- [**NMC2v3 Bring-Up Guide**](./docs/NMC2v3_Bring-Up_Guide_Rev8.pdf) (PDF) — photo walkthrough of taking a bare NMC board to a Linux prompt: software installation, cabling and connector locations, FPGA/eNVM programming, and Linux flashing.

---

## Maintainer Guide

The sections below cover recompiling the HSS bootloader and the tools distributed in the BSPs. They are not needed to boot the board with the provided BSP artifacts.

### 1. Environment Requirements

Ensure the xPack GNU RISC-V Embedded GCC toolchain (v15.2.0 or compatible) is installed and available in your system path:

```bash
export PATH=$PATH:/path/to/xpack-riscv-none-elf-gcc/bin
riscv-none-elf-gcc --version
```

Install host build tools:

```bash
sudo apt update && sudo apt install -y build-essential device-tree-compiler libyaml-dev libelf-dev libssl-dev
```

> The Linux boot path (`mpfs-nmc-linux-bsp`) has its own, separate environment requirements (WSL2/Ubuntu 22.04 + Buildroot dependencies) — see that repo's README rather than this section.

### 2. Compiling the HSS Bootloader

To compile the Hart Software Services eNVM wrapper binary (`hss-envm-wrapper-bm1-p0.bin`):

1. Navigate to the HSS repository root:

   ```bash
   cd MPFS_NMC_OS/hart-software-services
   ```

2. Launch the interactive command-line Kconfig generator to configure target board options (example: NMC2v3):

   ```bash
   make BOARD=NMC2v3 config
   ```

3. Clean the board target:

   ```bash
   make BOARD=NMC2v3 clean
   ```

4. Compile the eNVM wrapper binary using the xPack GCC toolchain:

   ```bash
   make BOARD=NMC2v3
   ```

### 3. Building the Payload Generator Tool (`hss-payload-generator`)

To build or update the standalone host binary generator stored in `mpfs-nmc-rtems-bsp/tools/`:

1. Navigate to the payload generator tool directory:

   ```bash
   cd MPFS_NMC_OS/hart-software-services/tools/hss-payload-generator
   ```

2. Compile the tool using the host C toolchain:

   ```bash
   make clean && make
   ```

3. Copy the compiled executable into the BSP tools folder for distribution:

   ```bash
   cp hss-payload-generator ../../../mpfs-nmc-rtems-bsp/tools/
   ```

### 4. Per-OS Artifacts

- **RTEMS** — If the device tree source (`.dts`) is modified, recompile the board `.dtb`:

  ```bash
  cd MPFS_NMC_OS/mpfs-nmc-rtems-bsp
  dtc -I dts -O dtb -o dts/mpfs-nmc-board.dtb dts/mpfs-nmc-uboot.dts
  ```

- **Linux** — Built entirely differently via [`buildroot-external-microchip`](https://github.com/linux4microchip/buildroot-external-microchip) layered on top of upstream Buildroot, run inside WSL2/Ubuntu 22.04 rather than the xPack toolchain and HSS repo used above. For environment setup, applying the NMC device tree/config overlay, building images, and flashing, see [`mpfs-nmc-linux-bsp/README.md`](./mpfs-nmc-linux-bsp/README.md).
