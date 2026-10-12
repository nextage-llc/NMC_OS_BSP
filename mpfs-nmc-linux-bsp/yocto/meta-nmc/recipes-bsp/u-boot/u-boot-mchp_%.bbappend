FILESEXTRAPATHS:prepend := "${THISDIR}/files:${NMC_BSP_DIR}/uboot:"
SRC_URI:append = " file://mpfs-nmc-uboot.dts file://nmc-uboot.cfg"

do_configure:prepend() {
    cp ${WORKDIR}/mpfs-nmc-uboot.dts ${S}/dts/upstream/src/riscv/microchip/mpfs-icicle-kit.dts
}
