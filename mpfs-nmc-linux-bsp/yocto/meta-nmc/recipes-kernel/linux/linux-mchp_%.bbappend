FILESEXTRAPATHS:prepend := "${NMC_BSP_DIR}/linux:"
SRC_URI:append = " file://mpfs-nmc-linux.dts"

do_configure:prepend() {
    cp ${WORKDIR}/mpfs-nmc-linux.dts ${S}/arch/riscv/boot/dts/microchip/mpfs-icicle-kit.dts
    cp ${WORKDIR}/mpfs-nmc-linux.dts ${S}/arch/riscv/boot/dts/microchip/mpfs-icicle-kit-prod.dts
}
