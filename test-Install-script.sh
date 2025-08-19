#!/bin/bash

vmIP=10.0.69.3
sshPort=22

function waitForBlockDev {
    sTime=0.1
    while ! lsblk | grep "nbd0" | grep "G"; do
      sleep "$sTime"
      sTime=$(echo "$sTime * 0.1" | bc)
    done
    echo "nbd0 connected"
}

if [[ $(id -u) = 0 ]]; then
    archInstallDisk="/var/lib/libvirt/images/arch-intall.qcow2"
    archTestDisk="/var/lib/libvirt/images/arch-test.qcow2"

    sudo virsh destroy arch-test-vm
    sudo virsh net-destroy default

    if [[ ! -f "$archInstallDisk" ]]; then
        wget -O "$archInstallDisk" https://gitlab.archlinux.org/archlinux/arch-boxes/-/package_files/10032/download
    fi

    qemu-img create -f qcow2 "$archTestDisk" 50G

    modprobe nbd max_part=8
    qemu-nbd -c /dev/nbd0 "$archTestDisk"
    waitForBlockDev

    parted /dev/nbd0 --script \
        mklabel gpt \
        mkpart "EFI" fat32 1MiB 1GiB \
        set 1 esp on \
        mkpart "rootfs" btrfs 1GiB 21GiB \
        mkpart "home" ext4 21GiB 45GiB \
        mkpart "swap" linux-swap 45GiB 100%

    mkfs.fat -F32 /dev/nbd0p1
    mkfs.btrfs /dev/nbd0p2
    mkfs.ext4 /dev/nbd0p3
    mkswap /dev/nbd0p4

    qemu-nbd -d /dev/nbd0
    
    echo "Copying pub key to authorized_keys, and VM pub key to known_hosts"
    qemu-nbd -c /dev/nbd0 "$archInstallDisk"
    waitForBlockDev
    mount /dev/nbd0p3 /mnt
    mkdir /mnt/root/.ssh
    if [[ ! -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        ssh-keygen -t ed25519 -f "$HOME"/.ssh/id_ed25519 -q -N ""
    fi
    cat "$HOME"/.ssh/id_ed25519.pub > /mnt/root/.ssh/authorized_keys
    cp ./Install.sh /mnt/
    cp ./arch-packages /mnt/
    umount /mnt

    qemu-nbd -d /dev/nbd0

    if ! virsh define ./arch-test-vm.xml; then
        virsh undefine arch-test-vm --nvram
        virsh define ./arch-test-vm.xml
    fi

    virsh attach-disk arch-test-vm "$archInstallDisk" vda --persistent --subdriver qcow2
    virsh attach-disk arch-test-vm "$archTestDisk" vdb --persistent --subdriver qcow2

    virsh dumpxml arch-test-vm | 
        sed -e '/<boot order/d' -e \
        '/<boot dev/d' -e \
        '/<target dev='\''vda'\''/a\      <boot order='\''1'\''/>' | 
        virsh define /dev/stdin

    if ! virsh net-define ./default.xml; then
        virsh net-undefine default
        virsh net-define ./default.xml
    fi

    virsh net-start default
    virsh net-autostart default

    virsh start arch-test-vm
    echo "VM booting..."

    waitTime=0.5
    attempts=1
    printf "\n\n"
    while ! ssh-keyscan "$vmIP" >/dev/null 2>&1; do
        printf "\e[1A\e[2K\e[1A\e[2K"
        printf "Connection attempts: %s\nWaiting for %s seconds\n" "$attempts" "$waitTime"
        ((attempts++))
        sleep "$waitTime"
        waitTime=$(echo "$waitTime * 1.5" | bc)
    done
    echo "Connection established"

    sed -i "/$vmIP/d" "$HOME"/.ssh/known_hosts
    ssh -t -p $sshPort -o StrictHostKeyChecking=no root@$vmIP 'pacman -Sy --noconfirm archlinux-keyring' >/dev/null 2>&1
    ssh -t -p $sshPort root@$vmIP 'pacman -Syu --noconfirm git'
    ssh -t -p $sshPort root@$vmIP 'pacman -Syuw --noconfirm $(cat "/arch-packages")'
    ssh -t -p $sshPort root@$vmIP 'source /Install.sh main'
else 
    echo "needs to be run as root"
fi
