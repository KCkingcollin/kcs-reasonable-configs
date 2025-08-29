#!/bin/bash

archTestDisk="/var/lib/libvirt/images/arch-test.raw"
vmIP=10.0.69.3
sshPort=22
vmName="arch-test-vm"
declare -a loopDevices

trap cleanup SIGINT SIGTERM

# arg 1: Which loop device to use (integer)
# arg 2: The location of the raw disk file
# If arg 3 or 4 are left blank then the block device will be connected without mounting it
# arg 3: The partition to mount (integer)
# arg 4: The location of the mount
function mountRawDisk {
    loopDevices[$1]="$(losetup -f --show "$2")" || exit 1
    partx -a "${loopDevices[$1]}"
    if [ "$#" -gt 2 ]; then
        mount "${loopDevices[$1]}"p"$3" "$4" || exit 1
    fi
}

# arg 1: Which loop device to disconnect (integer)
function umountRawDisk {
    umount -l "${loopDevices[$1]}"* &> /dev/null
    losetup -d "${loopDevices[$1]}" || return 1
}

function cleanup {
    for (( i=0; i<${#loopDevices[@]}; i++ )); do
        umountRawDisk $i
        echo -e "\n\033[31m[ FAIL ]\033[0m Test was stopped\n"
        exit 1
    done
}

function createTestEV {
    loopDevices[0]="$(losetup -j "$archTestDisk" | cut -d: -f1)"
    if [ "${loopDevices[0]}" != "" ]; then
        umountRawDisk 0
    fi
    sudo virsh destroy $vmName &> /dev/null
    sudo virsh net-destroy default &> /dev/null
    fallocate -l 50G "$archTestDisk"

    mountRawDisk 0 "$archTestDisk"

    parted "${loopDevices[0]}" --script \
        mklabel gpt \
        mkpart "EFI" fat32 1MiB 1GiB \
        set 1 esp on \
        mkpart "rootfs" btrfs 1GiB 21GiB \
        mkpart "home" ext4 21GiB 45GiB \
        mkpart "swap" linux-swap 45GiB 100% ||
        exit

    mkfs.fat -F32 "${loopDevices[0]}"p1 || exit
    mkfs.btrfs -f "${loopDevices[0]}"p2 || exit
    yes | mkfs.ext4 "${loopDevices[0]}"p3 || exit
    mkswap "${loopDevices[0]}"p4 || exit

    umountRawDisk 0
    
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
    unset InputList
    InputList=(
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

    Input=""
    for elm in "${InputList[@]}"; do
        Input+="$elm"'\n'
    done
    echo -e "$Input"
}

function runTest1 {
    createTestEV

    cleanInstall="y"
    replaceRepos="y"
    autoMount="y"
    bootDev="${loopDevices[0]}p1"
    rootDev="${loopDevices[0]}p2"
    homeDev="${loopDevices[0]}p3"
    swapDev="${loopDevices[0]}p4"
    rootPW="testPass"
    userName="testuser"
    userPass="testPass"
    machineName="testev"

    echo "running system test 1"
    mountRawDisk 0 "$archTestDisk"
    podman run -e testInput="$(createInput)" -it --rm --privileged \
        --device="${loopDevices[0]}":"${loopDevices[0]}" \
        test-install-ev || err=true && err=false
    umountRawDisk 0
    test1="Full instalation test\nInput:\n$(createInput)"
    if [ "$err" ]; then
        echo -e "\033[31m[ FAIL ]\033[0m $test1\n"
        return 1
    fi
    echo -e "\033[32m[ PASS ]\033[0m $test1\n"
}

function systemTest {
    runTest1

    virsh attach-disk $vmName "$archTestDisk" vda --persistent --subdriver raw
    virsh start $vmName
    echo "VM booting..."
}

if [[ $(id -u) = 0 ]]; then
    systemTest
    exit
else 
    echo "needs to be run as root"
fi
