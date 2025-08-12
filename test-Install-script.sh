#!/bin/bash

archInstallDisk="$HOME/.local/share/libvirt/images/arch-intall.qcow2"
archTestDisk="$HOME/.local/share/libvirt/images/arch-test.qcow2"

if [[ ! -f "$archInstallDisk" ]]; then
  wget -O "$archInstallDisk" https://gitlab.archlinux.org/archlinux/arch-boxes/-/package_files/10032/download
fi

qemu-img create -f qcow2 "$archTestDisk" 30G

sudo modprobe nbd max_part=8
sudo qemu-nbd -c /dev/nbd0 "$archTestDisk"

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

if ! virsh define ./test-arch-vm.xml; then
    virsh undefine arch-test-vm --nvram
    virsh define ./test-arch-vm.xml
fi

virsh attach-disk arch-test-vm "$archInstallDisk" vda --persistent  --subdriver qcow2
virsh attach-disk arch-test-vm "$archTestDisk" vdb --persistent  --subdriver qcow2

# changes the boot drive via redefining the xml config
virsh dumpxml arch-test-vm | 
    sed -e '/<boot order/d' -e \
    '/<boot dev/d' -e \
    '/<target dev='\''vda'\''/a\      <boot order='\''1'\''/>' | 
    virsh define /dev/stdin

virsh start arch-test-vm
