#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  Joke Distro Build Script (Ubuntu‑based)
#  This script:
#    1. Creates a working directory
#    2. Bootstraps a minimal Ubuntu filesystem
#    3. Enters a chroot to install packages + run custom scripts
#    4. Injects Easter eggs
#    5. Builds a bootable ISO
# ============================================================

DISTRO_NAME="cursedbuntu"
RELEASE="jammy"              # Ubuntu version
WORKDIR="$(pwd)/build"
ROOTFS="$WORKDIR/rootfs"
ISO_OUTPUT="$WORKDIR/${DISTRO_NAME}.iso"

# ------------------------------------------------------------
# 0. Check dependencies
# ------------------------------------------------------------
check_deps() {
    echo "[*] Checking dependencies..."
    for dep in debootstrap xorriso squashfs-tools grub-pc-bin grub-efi-amd64-bin; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Missing dependency: $dep"
            exit 1
        fi
    done
}

# ------------------------------------------------------------
# 1. Prepare working directory
# ------------------------------------------------------------
prepare_dirs() {
    echo "[*] Preparing directories..."
    rm -rf "$WORKDIR"
    mkdir -p "$ROOTFS"
}

# ------------------------------------------------------------
# 2. Bootstrap minimal Ubuntu filesystem
# ------------------------------------------------------------
bootstrap_rootfs() {
    echo "[*] Bootstrapping Ubuntu ($RELEASE)..."
    sudo debootstrap --arch=amd64 "$RELEASE" "$ROOTFS" http://archive.ubuntu.com/ubuntu/
}

# ------------------------------------------------------------
# 3. Copy custom files into rootfs BEFORE chroot
# ------------------------------------------------------------
inject_pre_chroot() {
    echo "[*] Injecting pre-chroot customizations..."
    sudo cp -r configs/* "$ROOTFS/" || true
    sudo cp -r branding/* "$ROOTFS/usr/share/" || true
}

# ------------------------------------------------------------
# 4. Enter chroot and run customization script
# ------------------------------------------------------------
run_chroot_customization() {
    echo "[*] Running chroot customization..."

    sudo cp scripts/customize-in-chroot.sh "$ROOTFS/customize.sh"

    sudo chroot "$ROOTFS" /bin/bash <<'EOF'
set -e

echo "[chroot] Updating package lists..."
apt update

echo "[chroot] Installing packages..."
apt install -y ubuntu-standard sudo curl neofetch

echo "[chroot] Running custom script..."
bash /customize.sh

echo "[chroot] Cleaning up..."
apt clean
rm /customize.sh

EOF
}

# ------------------------------------------------------------
# 5. Inject Easter eggs AFTER chroot
# ------------------------------------------------------------
inject_easter_eggs() {
    echo "[*] Adding Easter eggs..."
    sudo cp -r easter-eggs/* "$ROOTFS/usr/local/bin/" || true
    sudo chmod +x "$ROOTFS/usr/local/bin/"* || true
}

# ------------------------------------------------------------
# 6. Build ISO
# ------------------------------------------------------------
build_iso() {
    echo "[*] Building ISO..."

    mkdir -p "$WORKDIR/iso"

    # Copy rootfs into ISO structure
    sudo mksquashfs "$ROOTFS" "$WORKDIR/iso/filesystem.squashfs" -e boot

    # Copy bootloader files
    sudo mkdir -p "$WORKDIR/iso/boot/grub"
    sudo cp /usr/lib/grub/i386-pc/* "$WORKDIR/iso/boot/grub/"

    # Create GRUB config
    cat <<EOF | sudo tee "$WORKDIR/iso/boot/grub/grub.cfg"
set default=0
set timeout=3

menuentry "Boot $DISTRO_NAME" {
    linux /boot/vmlinuz root=/dev/ram0
    initrd /boot/initrd.img
}
EOF

    # Build ISO
    xorriso -as mkisofs \
        -o "$ISO_OUTPUT" \
        -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
        -c boot.cat \
        -b isolinux.bin \
        "$WORKDIR/iso"

    echo "[*] ISO created at: $ISO_OUTPUT"
}

# ------------------------------------------------------------
# Run all steps
# ------------------------------------------------------------
check_deps
prepare_dirs
bootstrap_rootfs
inject_pre_chroot
run_chroot_customization
inject_easter_eggs
build_iso

echo "[✓] Build complete!"
