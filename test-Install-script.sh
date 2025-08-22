#!/bin/bash

archTestDisk="/var/lib/libvirt/images/arch-test.qcow2"
vmIP=10.0.69.3
sshPort=22
vmName="arch-test-vm"

function waitForBlockDev {
    sTime=0.1
    while ! lsblk | grep "$1" | grep -q "G"; do
      sleep "$sTime"
      sTime=$(echo "$sTime * 1.25" | bc)
    done
    echo "/dev/$1 connected"
}

# arg 1: Which block dev to use (integer)
# arg 2: The location of the qcow2 img to mount
# If arg 3 or 4 are left blank then the block device will be connected without mounting it
# arg 3: The partition to mount (integer)
# arg 4: The location of the mount
function mountVirtDisk {
    modprobe nbd max_part=8
    qemu-nbd -c /dev/nbd"$1" "$2"
    waitForBlockDev nbd"$1"
    if [ "$#" -gt 2 ]; then
        mount /dev/nbd"$1"p"$3" "$4" | exit
    fi
}

# arg 1: Which block dev to disconnect (integer)
function umountVirtDisk {
    umount -l /dev/nbd"$1"* &> /dev/null
    qemu-nbd -d /dev/nbd"$1"
}

function createTestEV {
    sudo virsh destroy $vmName
    sudo virsh net-destroy default

    qemu-img create -f qcow2 "$archTestDisk" 50G

    mountVirtDisk 0 "$archTestDisk"

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

    umountVirtDisk 0
    
    if ! podman image exists kcs-reasonable-configs-install-ev; then
        echo "Did not find main install environment image, creating it now"
        podman build --dns 8.8.8.8 -t kcs-reasonable-configs-install-ev .
    fi

    if ! virsh define ./$vmName.xml >/dev/null 2>&1; then
        virsh undefine $vmName --nvram
        virsh define ./$vmName.xml
    fi

    if ! virsh net-define ./default.xml &> /dev/null; then
        virsh net-undefine default
        virsh net-define ./default.xml
    fi

    virsh net-start default
    virsh net-autostart default
}

function startAndConnect {
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
    bootDev="/dev/nbd0p1"
    rootDev="/dev/nbd0p2"
    homeDev="/dev/nbd0p3"
    swapDev="/dev/nbd0p4"
    rootPW="testPass"
    userName="test"
    userPass="testPass"
    machineName="testev"

    echo "running system test 1"
    mountVirtDisk 0 "$archTestDisk"
    podman build --build-arg testInput="$(createInput)" -f Dockerfile.test -t test-install-ev .
    podman run -it --rm --privileged test-install-ev /bin/bash
    podman rmi -f test-install-ev
    umountVirtDisk 0

    virsh attach-disk $vmName "$archTestDisk" vdb --persistent --subdriver qcow2
    virsh start $vmName
    echo "VM booting..."
}

if [[ $(id -u) = 0 ]]; then
    systemTest
else 
    echo "needs to be run as root"
fi
