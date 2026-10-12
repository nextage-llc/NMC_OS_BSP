# MPFS NMC Linux BSP (`mpfs-nmc-linux-bsp`)

This repository contains the Board Support Package (BSP) for running **Linux** on the Microchip PolarFire SoC (MPFS) NMC platform: the NMC device trees and U-Boot/Linux configuration, build-system integration for **Buildroot** and **Yocto**, and sample boot images for both.

---

## Start Here

Both build systems produce the same two things — an HSS-wrapped U-Boot **payload** flashed over YMODEM, and a **disk image** flashed over TFTP — from the same NMC device trees. Pick one; each guide is a complete, standalone walkthrough.

| I want to...                                   | Go to                                                    |
| ---------------------------------------------- | -------------------------------------------------------- |
| Build and boot Linux with **Buildroot**        | [`buildroot/README.md`](./buildroot/README.md)           |
| Build and boot Linux with **Yocto**            | [`yocto/README.md`](./yocto/README.md)                   |
| Just flash a pre-built image                   | [`sample/README.md`](./sample/README.md)                 |

|                    | Buildroot                                      | Yocto                                                        |
| ------------------ | ---------------------------------------------- | ------------------------------------------------------------ |
| Upstream base      | `buildroot-external-microchip` + Buildroot 2025.02.11 | `meta-mchp` (scarthgap), `linux4microchip-2026.04`   |
| How NMC changes go in | Copy `.config`s and DTS into the build tree | Add the `meta-nmc` layer                                     |
| Payload            | `payload.bin`                                  | `payload-yocto.bin`                                          |
| Disk image         | `sdcard.img` (`mpfs_icicle.itb` on partition 2) | `yocto.wic.gz` (`fitImage` + `boot.scr` on partition 1)     |
| Login              | `root` / `root`                                | `root` / no password                                         |
| First build        | ~1 hour                                        | several hours, ~100 GB disk                                  |

> Flash the payload and disk image from the same build system — the two U-Boots look for the kernel in different places.

---

## Repository Structure

```text
mpfs-nmc-linux-bsp/
├── uboot/                          # Shared by Buildroot and Yocto
│   ├── .config                     # U-Boot 2025.07-linux4microchip-2026.04 configuration (Buildroot applies it whole)
│   └── mpfs-nmc-uboot.dts          # U-Boot device tree source
├── linux/                          # Shared by Buildroot and Yocto
│   ├── .config                     # Kernel 6.18.17-linux4microchip-2026.04.1 configuration (Buildroot applies it whole)
│   └── mpfs-nmc-linux.dts          # Linux device tree source
├── buildroot/
│   ├── .config                     # Buildroot configuration
│   └── README.md                   # Buildroot build, flash and boot guide
├── yocto/
│   ├── meta-nmc/                   # Yocto layer: pulls in ../../uboot and ../../linux DTS + U-Boot fragment
│   └── README.md                   # Yocto build, flash and boot guide
└── sample/
    ├── buildroot/payload.bin       # Pre-built Buildroot HSS payload
    ├── yocto/payload-yocto.bin     # Pre-built Yocto HSS payload
    └── README.md                   # Where to get the full disk images (GitHub Releases)
```

**Where to make a change:**

- **Board hardware (pins, PHYs, peripherals):** edit the DTS in `uboot/` or `linux/`. Both build systems pick it up.
- **U-Boot or kernel options:** for Buildroot, update the full `.config` in `uboot/` or `linux/`. For Yocto, add a `.cfg` fragment in `yocto/meta-nmc` (see the Yocto guide's Known Issues).
- **Buildroot packages / rootfs:** `buildroot/.config`.
- **Yocto packages / rootfs:** a recipe or bbappend in `yocto/meta-nmc`.

---

## Before You Begin

- **The board must already be programmed** with the NMC FPGA design and the Hart Software Services (HSS) bootloader in eNVM. The HSS provides the UART0 prompt used to flash the payload.
- **Host tools:** WSL2 / Ubuntu 22.04 LTS (for building), Tera Term (serial terminals), and a TFTP server such as tftpd64.
- **Connections:** USB-to-serial on UART0 and UART1, and an Ethernet cable from the board to the host PC.

---

## Additional Resources

- [**NMC2v3 Bring-Up Guide (Buildroot)**](../docs/NMC2v3_Bring-Up_Guide_Rev8_Buildroot.pdf) (PDF) and [**NMC2v3 Bring-Up Guide (Yocto)**](../docs/NMC2v3_Bring-Up_Guide_Rev16_Yocto.pdf) (PDF) — supplementary photo walkthroughs, including software installation, cable wiring and connector locations (UART0/UART1 headers, Ethernet, power, FlashPro), and programming the FPGA design and HSS into eNVM.
