# MPFS NMC OS Boot Workspace (`MPFS_NMC_OS`)

*Internal maintainer guide for recompiling tools, HSS bootloaders, and updating the BSP artifacts.*

This workspace contains source repositories, toolchains, and build scripts for generating internal infrastructure binaries, bootloaders, and BSP tools for the PolarFire SoC NMC platform.

---

## Directory Structure

```text
MPFS_NMC_OS/
├── hart-software-services/     # Microchip HSS source code repository
└── mpfs-nmc-rtems-bsp/         # Distributed RTEMS Board Support Package
```

---

## 1. Environment Requirements

Ensure the xPack GNU RISC-V Embedded GCC toolchain (v15.2.0 or compatible) is installed and available in your system path:

```bash
riscv-none-elf-gcc --version
```

Install host build tools:

```bash
sudo apt update && sudo apt install -y build-essential device-tree-compiler libyaml-dev libelf-dev libssl-dev
```

---

## 2. Compiling the HSS Bootloader

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

---

## 3. Building the Payload Generator Tool (`hss-payload-generator`)

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

---

## 4. Compiling the Board Device Tree (`.dtb`)

If device tree sources (`.dts`) are modified:

```bash
cd MPFS_NMC_OS/mpfs-nmc-rtems-bsp
dtc -I dts -O dtb -o dts/mpfs-nmc-board.dtb dts/mpfs-nmc-uboot.dts
```