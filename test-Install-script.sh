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
    qemu-nbd -c /dev/nbd"$1" "$2" || exit
    waitForBlockDev nbd"$1"
    if [ "$#" -gt 2 ]; then
        mount /dev/nbd"$1"p"$3" "$4" || exit
    fi
}

# arg 1: Which block dev to disconnect (integer)
function umountVirtDisk {
    umount -l /dev/nbd"$1"* &> /dev/null
    qemu-nbd -d /dev/nbd"$1"
}

function createTestEV {
    qemu-nbd -d /dev/nbd0
    sudo virsh destroy $vmName &> /dev/null
    sudo virsh net-destroy default &> /dev/null
    truncate -s 0 "$archTestDisk"
    rm "$archTestDisk" &> /dev/null

    qemu-img create -f qcow2 "$archTestDisk" 50G

    mountVirtDisk 0 "$archTestDisk"

    parted /dev/nbd0 --script \
        mklabel gpt \
        mkpart "EFI" fat32 1MiB 1GiB \
        set 1 esp on \
        mkpart "rootfs" btrfs 1GiB 21GiB \
        mkpart "home" ext4 21GiB 45GiB \
        mkpart "swap" linux-swap 45GiB 100% ||
        exit

    mkfs.fat -F32 /dev/nbd0p1 || exit
    mkfs.btrfs /dev/nbd0p2 || exit
    mkfs.ext4 /dev/nbd0p3 || exit
    mkswap /dev/nbd0p4 || exit

    umountVirtDisk 0
    
    if ! podman image exists kcs-reasonable-configs-install-ev; then
        podman load -i ./install-ev-main.tar
    fi
    if podman image exists test-install-ev; then
        podman rmi -f test-install-ev
    fi
    podman build --dns 8.8.8.8 -f Dockerfile.run-test -t test-install-ev .

    if ! virsh define ./$vmName.xml &> /dev/null ; then
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
    userName="testuser"
    userPass="testPass"
    machineName="testev"

    runTest1() {
        echo "running system test 1"
        mountVirtDisk 0 "$archTestDisk"
        podman run -e testInput="$(createInput)" -it --rm --privileged \
            --device /dev/nbd0:/dev/nbd0 \
            test-install-ev &&\
        umountVirtDisk 0 || return 1
    }
    test1="Full instalation test\nInput:\n$(createInput)"
    if ! runTest1; then
        echo -e "\033[31m[ FAIL ]\033[0m $test1\n"
        return 1
    fi
    echo -e "\033[32m[ PASS ]\033[0m $test1\n"

    virsh attach-disk $vmName "$archTestDisk" vdb --persistent --subdriver qcow2
    virsh start $vmName
    echo "VM booting..."
}

if [[ $(id -u) = 0 ]]; then
    systemTest
    exit
else 
    echo "needs to be run as root"
fi
