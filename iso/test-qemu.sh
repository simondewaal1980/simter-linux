#!/bin/sh
# test-qemu.sh — start de ISO in een UEFI-VM met een lege schijf.
#
# Gebruik:
#   iso/test-qemu.sh [pad-naar.iso]
#
# De VM gebruikt KVM, 4 GiB RAM, een 24 GiB qcow2-schijf en OVMF (UEFI).
# De monitor-socket staat in iso/test/monitor.sock; het seriële log in
# iso/test/serial.log. Sluiten kan met:
#   echo quit | socat - UNIX-CONNECT:iso/test/monitor.sock
# of gewoon het QEMU-venster sluiten.

set -eu

ISO_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ISO=${1:-$ISO_DIR/out/quickshell-desktop-amd64.iso}
TEST_DIR=$ISO_DIR/test
DISK=$TEST_DIR/disk.qcow2
VARS=$TEST_DIR/OVMF_VARS_4M.fd
MONITOR=$TEST_DIR/monitor.sock
SERIAL=$TEST_DIR/serial.log
OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
OVMF_VARS=/usr/share/OVMF/OVMF_VARS_4M.fd

[ -r "$ISO" ] || {
    echo "test-qemu: ISO niet gevonden: $ISO" >&2
    exit 1
}
[ -r "$OVMF_CODE" ] || {
    echo "test-qemu: OVMF niet gevonden; installeer ovmf." >&2
    exit 1
}
command -v qemu-system-x86_64 >/dev/null || {
    echo "test-qemu: qemu-system-x86_64 ontbreekt." >&2
    exit 1
}

mkdir -p "$TEST_DIR"
[ -e "$VARS" ] || cp "$OVMF_VARS" "$VARS"
[ -e "$DISK" ] || qemu-img create -f qcow2 "$DISK" 24G >/dev/null
rm -f "$MONITOR" "$SERIAL"

exec qemu-system-x86_64 \
    -name "Quickshell Desktop test" \
    -machine q35,accel=kvm \
    -cpu host \
    -smp 4 \
    -m 4096 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$VARS" \
    -drive file="$DISK",if=virtio,format=qcow2 \
    -cdrom "$ISO" \
    -boot order=d \
    -device virtio-vga \
    -nic none \
    -display gtk,zoom-to-fit=on \
    -monitor unix:"$MONITOR",server,nowait \
    -serial file:"$SERIAL"
