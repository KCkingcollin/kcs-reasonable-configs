package lib

import (
	"fmt"
	"os"
	fp "path/filepath"
	"strings"
	"sync"
	"testing"
	sh "unix-shell"
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

	sh.RunS("swapoff", "-a")
	diskNum := len(LoopDevices)
	output := sh.RunS("losetup", "-j", rawDiskLoc)
	if output.Output == "" {
		out := sh.RunS("losetup", "-f", "--show", rawDiskLoc)
		if !out.Success {
			sh.CritError(out.Error, out.Output)
		}
		LoopDevices[diskNum] = out.Output
	} else {
		LoopDevices[diskNum] = strings.Split(output.Output, ":")[0]
	}
	sh.RunS("partx", "-a", LoopDevices[diskNum])

	return diskNum
} 

func UmountRawDisk(diskNum int) {
	LockDiskMounting.Lock()
	defer LockDiskMounting.Unlock()
	sh.Umount(LoopDevices[diskNum]+"*")
	sh.RunS("swapoff", LoopDevices[diskNum]+"*")
	sh.RunS("losetup", "-d", LoopDevices[diskNum])
	sh.RunS("swapon", "-a")
	delete(LoopDevices, diskNum)
}

func CreatePartitions(diskNum int) error {
	if LoopDevices[diskNum] == "" {sh.CritError(fmt.Sprintf("LoopDevices[%d] is empty", diskNum))}

	output := sh.RunS(
		`parted `+LoopDevices[diskNum]+` --script`,
		`mklabel gpt`,
		`mkpart "EFI" fat32 1MiB 1GiB`,
		`set 1 esp on`,
		`mkpart "rootfs" btrfs 1GiB 21GiB`,
		`mkpart "home" ext4 21GiB 45GiB`,
		`mkpart "swap" linux-swap 45GiB 100%`,
	)
	for !output.Success {
		return fmt.Errorf("error in parted: %w", output.Error)
	}

	if output := sh.RunS(`mkfs.fat -F32 "`+LoopDevices[diskNum]+`p1"`); !output.Success {
		return fmt.Errorf("error in mkfs fat: %w", output.Error)
	}
	if output := sh.RunS(`mkfs.btrfs -f "`+LoopDevices[diskNum]+`p2"`); !output.Success {
		return fmt.Errorf("error in mkfs btrfs: %w", output.Error)
	}
	if output := sh.RunS(`yes | mkfs.ext4 "`+LoopDevices[diskNum]+`p3"`); !output.Success {
		return fmt.Errorf("error in mkfs ext4: %w", output.Error)
	}
	if output := sh.RunS(`mkswap "`+LoopDevices[diskNum]+`p4"`); !output.Success {
		return fmt.Errorf("error in mkswap: %w", output.Error)
	}

	return nil
}

func MountThePartitions(diskNum int, mntLoc, testUser string) {
	sh.Mount(LoopDevices[diskNum]+"p2", fp.Join(mntLoc, "/"), "btrfs", "")
	sh.RunS("btrfs", "subvolume", "create", fp.Join(mntLoc, "@"))
	sh.Umount(mntLoc)
	sh.Mount(LoopDevices[diskNum]+"p2", fp.Join(mntLoc, "/"), "btrfs", "subvol=@")
	sh.Mkdir(fp.Join(mntLoc, "/boot/efi"))
	sh.Mkdir(fp.Join(mntLoc, "/home"))
	sh.Mount(LoopDevices[diskNum]+"p1", fp.Join(mntLoc, "/boot/efi"), "vfat", "")
	sh.Mount(LoopDevices[diskNum]+"p3", fp.Join(mntLoc, "/home"), "ext4", "")
	sh.Run("swapon", LoopDevices[diskNum]+"p4")
	sh.Cp("/kcs-reasonable-configs", fp.Join(mntLoc, "/kcs-reasonable-configs"))
	sh.Mkdir(fp.Join(mntLoc, "/var/cache/pacman"))
	sh.Cp("/var/cache/pacman/pkg", fp.Join(mntLoc, "/var/cache/pacman/pkg"))
	sh.Cp("/home/*/.cache/yay", fp.Join(mntLoc, "/home", testUser, ".cache/yay"))
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

