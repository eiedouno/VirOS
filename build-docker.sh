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
    debootstrap --arch=amd64 "$RELEASE" "$ROOTFS" http://archive.ubuntu.com/ubuntu/
}

# ------------------------------------------------------------
# 3. Copy custom files into rootfs BEFORE chroot
# ------------------------------------------------------------
inject_pre_chroot() {
    echo "[*] Injecting pre-chroot customizations..."
    if [ -d "etc" ]; then
        cp -r etc/* "$ROOTFS/etc/"
    fi
    if [ -d "usr/share" ]; then
        cp -r usr/share/* "$ROOTFS/usr/share/"
    fi

    # Copy compiled C++ tools into rootfs
    if [ -d "build-cpp" ]; then
        cp build-cpp/cursed-cat "$ROOTFS/usr/local/bin/cat"
        cp build-cpp/cursed-ls "$ROOTFS/usr/local/bin/ls"
        cp build-cpp/cursed-vim "$ROOTFS/usr/local/bin/vim"
        cp build-cpp/cursed-help "$ROOTFS/usr/local/bin/help"
        echo "[*] Injected cursed-vim as /usr/local/bin/vim"
        echo "[*] Injected cursed-cat as /usr/local/bin/cat"
        echo "[*] Injected cursed-ls as /usr/local/bin/ls"
        echo "[*] Injected cursed-help as /usr/local/bin/help"
    fi
}

# ------------------------------------------------------------
# 4. Enter chroot and run customization script
# ------------------------------------------------------------
run_chroot_customization() {
    echo "[*] Running chroot customization..."

    if [ -f "scripts/chroot.sh" ]; then
        cp scripts/chroot.sh "$ROOTFS/customize.sh"
        HAVE_CUSTOM=true
    else
        echo "[!] scripts/chroot.sh not found, skipping custom script."
        HAVE_CUSTOM=false
    fi

    chroot "$ROOTFS" /bin/bash <<EOF
set -e
echo "[chroot] Updating package lists..."
apt update

echo "[chroot] Installing packages..."
apt install -y ubuntu-standard sudo curl linux-image-generic casper

echo "[chroot] Running custom script..."
if [ "$HAVE_CUSTOM" = true ] && [ -f /customize.sh ]; then bash /customize.sh
fi

echo "[chroot] Cleaning up..."
apt clean
rm -f /customize.sh
EOF
}

# ------------------------------------------------------------
# 5. Build ISO
# ------------------------------------------------------------
build_iso() {
    echo "[*] Building ISO..."
    local ISO_DIR="$WORKDIR/iso"
    mkdir -p "$ISO_DIR/boot/grub"

    # Compress rootfs into /casper/ (required by casper)
    mkdir -p "$ISO_DIR/casper"
    mksquashfs "$ROOTFS" "$ISO_DIR/casper/filesystem.squashfs" -e boot

    # Copy kernel and initrd into /casper/
    VMLINUZ=$(ls "$ROOTFS/boot/vmlinuz-"* 2>/dev/null | sort -V | tail -1)
    INITRD=$(ls "$ROOTFS/boot/initrd.img-"* 2>/dev/null | sort -V | tail -1)

    if [ -z "$VMLINUZ" ] || [ -z "$INITRD" ]; then
        echo "[-] Kernel or initrd not found in rootfs."
        exit 1
    fi

    cp "$VMLINUZ" "$ISO_DIR/casper/vmlinuz"
    cp "$INITRD"  "$ISO_DIR/casper/initrd"

    # .disk/info required by casper to identify the medium
    mkdir -p "$ISO_DIR/.disk"
    echo "$DISTRO_NAME" > "$ISO_DIR/.disk/info"

    # Write shared grub.cfg pointing to /casper/
    cat > "$ISO_DIR/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=3
menuentry "Boot $DISTRO_NAME" {
    linux /casper/vmlinuz boot=casper quiet splash
    initrd /casper/initrd
}
EOF

    # Build GRUB EFI image
    grub-mkstandalone \
        --format=x86_64-efi \
        --output="$ISO_DIR/boot/grub/bootx64.efi" \
        --modules="part_gpt part_msdos fat iso9660 normal boot linux echo configfile search" \
        "boot/grub/grub.cfg=$ISO_DIR/boot/grub/grub.cfg"

    # Create EFI FAT image
    local EFI_IMG="$WORKDIR/efiboot.img"
    dd if=/dev/zero of="$EFI_IMG" bs=1M count=64
    mformat -i "$EFI_IMG" -F ::
    mmd -i "$EFI_IMG" ::/EFI ::/EFI/BOOT
    mcopy -i "$EFI_IMG" "$ISO_DIR/boot/grub/bootx64.efi" ::/EFI/BOOT/

    # Build GRUB BIOS image using grub-mkimage
    grub-mkimage \
        -O i386-pc \
        -o "$WORKDIR/core.img" \
        -p /boot/grub \
        biosdisk iso9660 normal linux configfile search

    cat /usr/lib/grub/i386-pc/cdboot.img "$WORKDIR/core.img" > "$ISO_DIR/boot/grub/bios.img"

    # Copy GRUB i386-pc modules so they can be loaded at runtime
    cp -r /usr/lib/grub/i386-pc "$ISO_DIR/boot/grub/i386-pc"

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
build_iso
echo "[✓] Build complete!"
