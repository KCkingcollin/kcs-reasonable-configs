#!/bin/bash

archTestDisk="/var/lib/libvirt/images/arch-test.raw"
vmIP=10.0.69.3
sshPort=22
testUserName="testuser"
vmName="arch-test-vm"

trap cleanup SIGINT SIGTERM

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

function containerTestSetup {
    cp .zshrc /root/
    cp .zshrc /home/arch/
    cp ./etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist
    cp ./etc/pacman.conf /etc/pacman.conf
}

function createTestEV {
    sudo virsh destroy $vmName &> /dev/null
    sudo virsh net-destroy default &> /dev/null

    mv "$archTestDisk" "$archTestDisk".ded &> /dev/null
    rm "$archTestDisk".ded &> /dev/null &
    fallocate -l 50G "$archTestDisk"

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
        if [ "$elm" != "" ]; then
            Input+="$elm"'\n'
        fi
    done
    echo -e "$Input"
}

function runTest2 {
    if createTestEV; then
        cleanInstall="n"
        replaceRepos=""
        autoMount=""
        bootDev=""
        rootDev=""
        homeDev=""
        swapDev=""
        rootPW="testPass"
        userName="$testUserName"
        userPass="testPass"
        machineName="testev"

        echo "Copying project dir to a tar"
        tar -C "$(pwd)" -cf /tmp/src.tar .

        if $1; then 
            Fn="/bin/zsh -c \"/kcs-reasonable-configs/Install; /bin/zsh\""
        else
            Fn="echo -e \"$(createInput)\" | /bin/zsh -c /kcs-reasonable-configs/Install"
        fi

        echo "running system test 2..."
        mountRawDisk 0 "$archTestDisk"
        podman run -it --rm --privileged \
            -v /tmp/src.tar:/tmp/src.tar:ro \
            kcs-reasonable-configs-install-ev \
            bash -c "$(declare -f containerAutoMount containerTestSetup); \
            tar -C . -xf /tmp/src.tar && containerTestSetup || return 1;
            containerAutoMount \"${loopDevices[0]}\" || return 1;
            arch-chroot /mnt bash -c '$Fn' || return 1;" &&\
            err=false || err=true
        umountRawDisk 0
    else 
        err=true
    fi
    test1="Chroot instalation test\nInput:\n$(createInput)"
    if $err ; then
        echo -e "\033[31m[ FAIL ]\033[0m $test1\n\n"
        return 1
    fi
    echo -e "\033[32m[ PASS ]\033[0m $test1\n\n"

    virsh attach-disk $vmName "$archTestDisk" vda --persistent --subdriver raw
    virsh start $vmName
    echo "VM booting..."
}

function unitTest {
    if createTestEV; then
        echo "Copying project dir to a tar"
        tar -C "$(pwd)" -cf /tmp/src.tar .

        runContainer() {
            podman run -it --rm --privileged \
                -v /tmp/src.tar:/tmp/src.tar:ro \
                -v "$archTestDisk":/images/arch-test.raw \
                -v /dev:/dev \
                kcs-reasonable-configs-install-ev \
                bash -c "$(declare -f containerTestSetup); \
                tar -C . -xf /tmp/src.tar && containerTestSetup && \
                $Fn" && \
                err=false || err=true
            }

        if [[ $1 == "-m" ]]; then
            Fn="zsh"
        elif [[ $1 == "-u" ]]; then
            echo "running unit tests..."
            Fn="go test ${*:2} ./lib"
        else
            echo "running unit tests..."
            Fn="go test $* ./lib"
        fi
        runContainer

        if [[ $1 != "-m" && $1 != "-u" ]]; then 
            Fn="go test $* ."
            runContainer
            if ! $err; then
                virsh attach-disk $vmName "$archTestDisk" vda --persistent --subdriver raw
                virsh start $vmName
                echo "VM booting..."
            fi
        fi
    else
        err=true
    fi
    if $err ; then
        echo -e "\033[31m[ FAIL ]\033[0m\n"
        return 1
    fi
    echo -e "\033[32m[ PASS ]\033[0m\n"
}

if [[ $(id -u) = 0 ]]; then
    unitTest "$@" || exit 1
    exit
else 
    echo "needs to be run as root"
fi
