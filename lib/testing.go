package lib

import (
	"fmt"
	"os"
	fp "path/filepath"
	"strings"
	"sync"
	"testing"
)

const RawDiskLocation = string("/images/arch-test.raw")

var (
	MntLoc 				string
	MainRootFD 			*os.File
	LoopDevices			= make(map[int]string)
	LockDiskMounting 	sync.Mutex
)

// arg 1: Which loop device to use (integer)
// arg 2: The location of the raw disk file
func MountRawDisk(rawDiskLoc string) int {
	LockDiskMounting.Lock()
	defer LockDiskMounting.Unlock()

	diskNum := len(LoopDevices)
	output := Run("losetup", "-j", rawDiskLoc, "-F noStdout")
	if output.Output == "" {
		out := Run("losetup", "-f", "--show", rawDiskLoc, "-F noStdout")
		if !out.Success {
			CritError(out.Error, out.Output)
		}
		LoopDevices[diskNum] = out.Output
	} else {
		LoopDevices[diskNum] = strings.Split(output.Output, ":")[0]
	}
	Run("partx", "-a", LoopDevices[diskNum], "-F noStdout")

	return diskNum
} 

func UmountRawDisk(diskNum int) {
	LockDiskMounting.Lock()
	defer LockDiskMounting.Unlock()
	Umount(LoopDevices[diskNum]+"*")
	Run("swapoff", LoopDevices[diskNum]+"*", "-F noStdout")
	Run("losetup", "-d", LoopDevices[diskNum], "-F noStdout")
	delete(LoopDevices, diskNum)
}

func CreatePartitions(diskNum int) error {
	if LoopDevices[diskNum] == "" {CritError(fmt.Sprintf("LoopDevices[%d] is empty", diskNum))}

	output := Run(
		`parted `+LoopDevices[diskNum]+` --script`,
		`mklabel gpt`,
		`mkpart "EFI" fat32 1MiB 1GiB`,
		`set 1 esp on`,
		`mkpart "rootfs" btrfs 1GiB 21GiB`,
		`mkpart "home" ext4 21GiB 45GiB`,
		`mkpart "swap" linux-swap 45GiB 100%`,
		`-F noStdout`,
	)
	for !output.Success {
		return fmt.Errorf("error in parted: %v", output.Error)
	}

	if output := Run(`mkfs.fat -F32 "`+LoopDevices[diskNum]+`p1"`, "-F noStdout"); !output.Success {
		return fmt.Errorf("error in mkfs fat: %v", output.Error)
	}
	if output := Run(`mkfs.btrfs -f "`+LoopDevices[diskNum]+`p2"`, "-F noStdout"); !output.Success {
		return fmt.Errorf("error in mkfs btrfs: %v", output.Error)
	}
	if output := Run(`yes | mkfs.ext4 "`+LoopDevices[diskNum]+`p3"`, "-F noStdout"); !output.Success {
		return fmt.Errorf("error in mkfs ext4: %v", output.Error)
	}
	if output := Run(`mkswap "`+LoopDevices[diskNum]+`p4"`, "-F noStdout"); !output.Success {
		return fmt.Errorf("error in mkswap: %v", output.Error)
	}

	return nil
}

func MountThePartitions(diskNum int) {
	Mount(LoopDevices[diskNum]+"p2", fp.Join(MntLoc, "/"), "btrfs", "")
	Run("btrfs", "subvolume", "create", fp.Join(MntLoc, "@"), "-F noStdout")
	Umount(MntLoc)
	Mount(LoopDevices[diskNum]+"p2", fp.Join(MntLoc, "/"), "btrfs", "subvol=@")
	Mkdir(fp.Join(MntLoc, "/boot/efi"))
	Mkdir(fp.Join(MntLoc, "/home"))
	Mount(LoopDevices[diskNum]+"p1", fp.Join(MntLoc, "/boot/efi"), "vfat", "")
	Mount(LoopDevices[diskNum]+"p3", fp.Join(MntLoc, "/home"), "ext4", "")
	Run("swapon", LoopDevices[diskNum]+"p4")
	Cp("/kcs-reasonable-configs", fp.Join(MntLoc, "/kcs-reasonable-configs"))
	Mkdir(fp.Join(MntLoc, "/var/cache/pacman"))
	Cp("/var/cache/pacman/pkg", fp.Join(MntLoc, "/var/cache/pacman/pkg"))
}

func IsContainer() bool {
	if _, err := os.Stat("/.dockerenv"); err == nil {
		return true
	}
	if _, err := os.Stat("/run/.containerenv"); err == nil {
		return true
	}
	return false
}

func MustContain(t *testing.T) {
	if !IsContainer() {
		t.Skip("Skipping test because it must be run inside a container.")
	}
}

