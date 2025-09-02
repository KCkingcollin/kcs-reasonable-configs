#!/bin/bash

archTestDisk="/var/lib/libvirt/images/arch-test.raw"
vmIP=10.0.69.3
sshPort=22
vmName="arch-test-vm"
testInput=""
declare -a loopDevices

trap cleanup SIGINT SIGTERM

function containerAutoMount {
    mount "$2" /mnt &&
    cd /mnt &&
    btrfs subvolume create @ &&
    cd .. &&
    umount -l /mnt || return 1

    mount -o subvol=@ "$2"
}

function containerTest {
    cp .zshrc /root/
    cp .zshrc /home/arch/
    cp ./etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist
    echo -e "$testInput" | /bin/zsh -c './Install' || umount -lf /mnt &> /dev/null
}

function containerManualTest {
    cp .zshrc /root/
    cp .zshrc /home/arch/
    cp ./etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist
    /bin/zsh -c './Install'
    /bin/zsh
    umount -lf /mnt &> /dev/null
}

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

    mv "$archTestDisk" "$archTestDisk".ded &> /dev/null
    rm "$archTestDisk".ded &> /dev/null &
    fallocate -l 50G "$archTestDisk"

    mountRawDisk 0 "$archTestDisk"

    parted "${loopDevices[0]}" --script \
        mklabel gpt \
        mkpart "EFI" fat32 1MiB 1GiB \
        set 1 esp on \
        mkpart "rootfs" btrfs 1GiB 21GiB \
        mkpart "home" ext4 21GiB 45GiB \
        mkpart "swap" linux-swap 45GiB 100% ||
        return 1

    mkfs.fat -F32 "${loopDevices[0]}"p1 || return 1
    mkfs.btrfs "${loopDevices[0]}"p2 || return 1
    mkfs.ext4 "${loopDevices[0]}"p3 || return 1
    mkswap "${loopDevices[0]}"p4 || return 1

    umountRawDisk 0
    
    if ! podman image exists kcs-reasonable-configs-install-ev; then
        podman build --dns 8.8.8.8 -f Dockerfile.main-ev -t kcs-reasonable-configs-install-ev .
    fi

    go build . || return 1

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
    if createTestEV; then
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

        echo "Copying project dir to a tar"
        tar -C "$(pwd)" -cf /tmp/src.tar .

        echo "running system test 1..."
        mountRawDisk 0 "$archTestDisk"
        if [ "$1" == "-m" ]; then 
            podman run -it --rm --privileged \
                -v /tmp/src.tar:/tmp/src.tar:ro \
                kcs-reasonable-configs-install-ev \
                bash -c "$(declare -f containerManualTest); tar -C . -xf /tmp/src.tar; containerManualTest" &&\
                err=false || err=true
        else
            podman run -e testInput="$(createInput)" -it --rm --privileged \
                -v /tmp/src.tar:/tmp/src.tar:ro \
                kcs-reasonable-configs-install-ev \
                bash -c "$(declare -f containerTest); tar -C . -xf /tmp/src.tar; containerTest" &&\
                err=false || err=true
        fi
        umountRawDisk 0
    else 
        err=true
    fi
    test1="Full instalation test\nInput:\n$(createInput)"
    if $err ; then
        echo -e "\033[31m[ FAIL ]\033[0m $test1\n"
        return 1
    fi
    echo -e "\033[32m[ PASS ]\033[0m $test1\n"

    virsh attach-disk $vmName "$archTestDisk" vda --persistent --subdriver raw
    virsh start $vmName
    echo "VM booting..."
}

function systemTest {
    runTest1 "$1"
}

if [[ $(id -u) = 0 ]]; then
    systemTest "$1"
    exit
else 
    echo "needs to be run as root"
fi
