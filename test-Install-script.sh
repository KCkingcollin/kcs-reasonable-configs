#!/bin/bash

if [[ ! -f "arch-intall.qcow2" ]]; then
  wget -O arch-intall.qcow2 https://gitlab.archlinux.org/archlinux/arch-boxes/-/package_files/10032/download
fi

qemu-img create -f qcow2 arch-test.qcow2 30G

sudo modprobe nbd max_part=8
sudo qemu-nbd -c /dev/nbd0 arch-test.qcow2

sudo parted /dev/nbd0 --script \
    mklabel gpt \
    mkpart "EFI" fat32 1MiB 1GiB \
    set 1 esp on \
    mkpart "rootfs" btrfs 1GiB 11GiB \
    mkpart "home" ext4 11GiB 25GiB \
    mkpart "swap" linux-swap 25GiB 100%

sudo mkfs.fat -F32 /dev/nbd0p1
sudo mkfs.btrfs /dev/nbd0p2
sudo mkfs.ext4 /dev/nbd0p3
sudo mkswap /dev/nbd0p4

sudo qemu-nbd -d /dev/nbd0
