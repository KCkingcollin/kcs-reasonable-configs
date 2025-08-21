#!/bin/bash

archInstallName="arch-install.qcow2"
archInstallDisk="/var/lib/libvirt/images/$archInstallName"
archTestDisk="/var/lib/libvirt/images/arch-test.qcow2"
vmIP=10.0.69.3
sshPort=22
vmName="arch-test-vm"

function waitForBlockDev {
    sTime=0.1
    while ! lsblk | grep "nbd0" | grep "G"; do
      sleep "$sTime"
      sTime=$(echo "$sTime * 0.1" | bc)
    done
    echo "nbd0 connected"
}

function createTestEV {
    sudo virsh destroy $vmName
    sudo virsh net-destroy default

    if [[ ! -f "$archInstallName" ]]; then
        wget -O "$archInstallName" https://gitlab.archlinux.org/archlinux/arch-boxes/-/package_files/10032/download
    fi

    cp "$archInstallName" "$archInstallDisk"

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
    sed -i 's/^#*UseDNS .*/UseDNS no/' /mnt/etc/ssh/sshd_config
    sed -i 's/^#*GSSAPIAuthentication .*/GSSAPIAuthentication no/' /mnt/etc/ssh/sshd_config
    sed -i 's/^#*MaxAuthTries .*/MaxAuthTries 1000/' /mnt/etc/ssh/sshd_config
    mkdir /mnt/kcs-reasonable-configs
    cp -r ./.* ./* /mnt/kcs-reasonable-configs/
    arch-chroot /mnt pacman -Scc --noconfirm
    rsync -a --info=progress2 /var/cache/pacman/pkg/* /mnt/var/cache/pacman/pkg/
    mkdir /mnt/yay-cache
    rsync -a --info=progress2 "$(getent passwd "$SUDO_USER" | cut -d: -f6)"/.cache/yay/* /mnt/yay-cache/
    cp etc/pacman.conf /mnt/etc/pacman.conf
    cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist
    arch-chroot /mnt timedatectl set-timezone "$(timedatectl | grep "Time zone" | sed "s/ *Time zone: //" | sed "s/ .*//")"
    arch-chroot /mnt pacman-key --init
    arch-chroot /mnt pacman-key --populate archlinux
    arch-chroot /mnt pacman -Sy --noconfirm archlinux-keyring
    arch-chroot /mnt pacman -Suw --noconfirm $(cat "./arch-packages")
    arch-chroot /mnt pacman -S --noconfirm git
    pacman -Scc --noconfirm
    rsync -a --info=progress2 /mnt/var/cache/pacman/pkg/* /var/cache/pacman/pkg/
    umount /mnt
    qemu-nbd -d /dev/nbd0

    if ! virsh define ./$vmName.xml >/dev/null 2>&1; then
        virsh undefine $vmName --nvram
        virsh define ./$vmName.xml
    fi

    virsh attach-disk $vmName "$archInstallDisk" vda --persistent --subdriver qcow2
    virsh attach-disk $vmName "$archTestDisk" vdb --persistent --subdriver qcow2

    virsh dumpxml $vmName | 
        sed -e '/<boot order/d' -e \
        '/<boot dev/d' -e \
        '/<target dev='\''vda'\''/a\      <boot order='\''1'\''/>' | 
        virsh define /dev/stdin

    if ! virsh net-define ./default.xml &> /dev/null; then
        virsh net-undefine default
        virsh net-define ./default.xml
    fi

    virsh net-start default
    virsh net-autostart default

    virsh start $vmName
    echo "VM booting..."

    waitTime=0.5
    attempts=1
    waited=$waitTime
    printf "\n\n\n"
    while ! nc -z -w 1 $vmIP $sshPort; do
        if [[ attempts -gt 30 ]]; then
            echo "Failed to connect to VM"
            exit
        fi
        printf "\e[1A\e[2K\e[1A\e[2K\e[1A\e[2K"
        printf "Connection attempts: %s\nWaiting for %s seconds\nWaited %s seconds\n" "$attempts" "$waitTime" "$waited"
        ((attempts++))
        sleep "$waitTime"
        waitTime=$(echo "$waitTime * 1.25" | bc)
        waited=$(echo "$waitTime + $waited" | bc)
    done

    sed -i "/$vmIP/d" "$HOME"/.ssh/known_hosts
    ssh-keyscan "$vmIP" | grep "ed25519" >> "$HOME"/.ssh/known_hosts
    echo "Connection established"
}

function createInput {
    unset test1InputList
    test1InputList=(
        "$cleanInstall" 
        "$replaceRepos" 
        "$autoMount" 
        "$bootDev" 
        "$rootDev" 
        "$homeDev" 
        "$swapDev" 
        "$rootPW" "$rootPW" 
        "$userName" 
        "$userPass" "$userPass" 
        "$machineName"
    )

    test1Input=""
    for elm in "${test1InputList[@]}"; do
        test1Input+="$elm"'\n'
    done
    echo -e "$test1Input"
}

function systemTest {
    createTestEV

    cleanInstall="y"
    replaceRepos="y"
    autoMount="y"
    bootDev="/dev/vdb1"
    rootDev="/dev/vdb2"
    homeDev="/dev/vdb3"
    swapDev="/dev/vdb4"
    rootPW="testPass"
    userName="test"
    userPass="testPass"
    machineName="testev"

    test1Input=$(createInput)

    echo "running system test 1"
    ssh -t -p $sshPort root@$vmIP "echo -e \"$test1Input\" | bash -c \"cd /kcs-reasonable-configs && source ./Install.sh\""
}

if [[ $(id -u) = 0 ]]; then
    systemTest
else 
    echo "needs to be run as root"
fi
