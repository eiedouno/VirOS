#!/usr/bin/env bash
set -euo pipefail

DISTRO_NAME="VirOS"
RELEASE="jammy"
WORKDIR="$(pwd)/build"
ROOTFS="$WORKDIR/rootfs"
ISO_OUTPUT="$WORKDIR/${DISTRO_NAME}.iso"

# ------------------------------------------------------------
# 0. Check dependencies
# ------------------------------------------------------------
check_deps() {
    echo "[*] Checking dependencies..."
    for dep in debootstrap xorriso mksquashfs grub-mkstandalone mformat; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "[-] Missing dependency: $dep"
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
    if [ -d "etc" ]; then
        sudo cp -r etc/* "$ROOTFS/etc/"
    fi
    if [ -d "usr/share" ]; then
        sudo cp -r usr/share/* "$ROOTFS/usr/share/"
    fi

    # Copy compiled C++ tools into rootfs
    if [ -d "build-cpp" ]; then
        sudo cp build-cpp/cursed-cat "$ROOTFS/usr/local/bin/cat"
        sudo cp build-cpp/cursed-ls "$ROOTFS/usr/local/bin/ls"
        echo "[*] Injected cursed-cat as /usr/local/bin/cat"
        echo "[*] Injected cursed-ls as /usr/local/bin/ls"
    fi
}

# ------------------------------------------------------------
# 4. Enter chroot and run customization script
# ------------------------------------------------------------
run_chroot_customization() {
    echo "[*] Running chroot customization..."

    if [ -f "scripts/chroot.sh" ]; then
        sudo cp scripts/chroot.sh "$ROOTFS/customize.sh"
        HAVE_CUSTOM=true
    else
        echo "[!] scripts/chroot.sh not found, skipping custom script."
        HAVE_CUSTOM=false
    fi

    sudo chroot "$ROOTFS" /bin/bash <<EOF
set -e
echo "[chroot] Updating package lists..."
apt update

echo "[chroot] Installing packages..."
apt install -y ubuntu-standard sudo curl linux-image-generic

echo "[chroot] Running custom script..."
if [ "$HAVE_CUSTOM" = true ] && [ -f /customize.sh ]; then
    bash /customize.sh
fi

echo "[chroot] Cleaning up..."
apt clean
rm -f /customize.sh
EOF
}

# ------------------------------------------------------------
# 5. (Placeholder) Easter eggs
# ------------------------------------------------------------
inject_easter_eggs() {
    echo "[*] Injecting easter eggs... (not yet implemented)"
    # Add your easter egg logic here
}

# ------------------------------------------------------------
# 6. Build ISO
# ------------------------------------------------------------
build_iso() {
    echo "[*] Building ISO..."
    local ISO_DIR="$WORKDIR/iso"
    mkdir -p "$ISO_DIR/boot/grub"

    # Compress rootfs (exclude /boot from squashfs — it goes in ISO directly)
    sudo mksquashfs "$ROOTFS" "$ISO_DIR/filesystem.squashfs" -e boot

    # Copy kernel and initrd from rootfs into ISO boot dir
    VMLINUZ=$(ls "$ROOTFS/boot/vmlinuz-"* 2>/dev/null | sort -V | tail -1)
    INITRD=$(ls "$ROOTFS/boot/initrd.img-"* 2>/dev/null | sort -V | tail -1)

    if [ -z "$VMLINUZ" ] || [ -z "$INITRD" ]; then
        echo "[-] Kernel or initrd not found in rootfs. Make sure linux-image-generic was installed."
        exit 1
    fi

    sudo cp "$VMLINUZ" "$ISO_DIR/boot/vmlinuz"
    sudo cp "$INITRD"  "$ISO_DIR/boot/initrd.img"

    # Build GRUB EFI image
    sudo grub-mkstandalone \
        --format=x86_64-efi \
        --output="$ISO_DIR/boot/grub/bootx64.efi" \
        --modules="part_gpt part_msdos fat iso9660 normal boot linux echo configfile search" \
        "boot/grub/grub.cfg=/dev/stdin" <<EOF
set default=0
set timeout=3
menuentry "Boot $DISTRO_NAME" {
    linux /boot/vmlinuz boot=live quiet splash
    initrd /boot/initrd.img
}
EOF

    # Create EFI FAT image
    local EFI_IMG="$WORKDIR/efiboot.img"
    dd if=/dev/zero of="$EFI_IMG" bs=1M count=64 #You can also try anything from 20-64. 64 and 32 are best though
    mformat -i "$EFI_IMG" -F ::
    mmd -i "$EFI_IMG" ::/EFI ::/EFI/BOOT
    mcopy -i "$EFI_IMG" "$ISO_DIR/boot/grub/bootx64.efi" ::/EFI/BOOT/

    # Write GRUB config for legacy BIOS fallback
    sudo grub-mkstandalone \
        --format=i386-pc \
        --output="$WORKDIR/core.img" \
        --modules="biosdisk iso9660 normal boot linux echo configfile search" \
        "boot/grub/grub.cfg=/dev/stdin" <<EOF
set default=0
set timeout=3
menuentry "Boot $DISTRO_NAME" {
    linux /boot/vmlinuz boot=live quiet splash
    initrd /boot/initrd.img
}
EOF
    cat /usr/lib/grub/i386-pc/cdboot.img "$WORKDIR/core.img" > "$WORKDIR/bios.img"

    # Build final hybrid ISO
    xorriso -as mkisofs \
        -o "$ISO_OUTPUT" \
        -iso-level 3 \
        -full-iso9660-filenames \
        -volid "$DISTRO_NAME" \
        -eltorito-boot boot/grub/bios.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog boot/grub/boot.cat \
        --grub2-boot-info \
        --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
        -eltorito-alt-boot \
        -e --interval:appended_partition_2:all:: \
        -no-emul-boot \
        -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B "$EFI_IMG" \
        "$ISO_DIR"

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
