package lib

import (
	"fmt"
	"os"
	fp "path/filepath"
	"strings"
	"testing"
)

const RawDiskLocation = string("/images/arch-test.raw")

var (
	MntLoc 			string
	MainRootFD 		*os.File
	LoopDevices		= make(map[int]string)
)

// arg 1: Which loop device to use (integer)
// arg 2: The location of the raw disk file
func MountRawDisk(diskNum int, rawDiskLoc string) {
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
} 

func UmountRawDisk(diskNum int) {
	Umount(LoopDevices[diskNum]+"*")
	Run("swapoff", "-a")
	Run("losetup", "-d", LoopDevices[diskNum], "-F noStdout")
}

func CreatePartitions() error {
	MountRawDisk(0, RawDiskLocation)
	defer UmountRawDisk(0)

	if LoopDevices[0] == "" {CritError("LoopDevices[0] is empty")}
	Run("wipefs", LoopDevices[0])

	output := Run(
		`parted `+LoopDevices[0]+` --script`,
		`mklabel gpt`,
		`mkpart "EFI" fat32 1MiB 1GiB`,
		`set 1 esp on`,
		`mkpart "rootfs" btrfs 1GiB 21GiB`,
		`mkpart "home" ext4 21GiB 45GiB`,
		`mkpart "swap" linux-swap 45GiB 100%`,
		`-F noStdout`,
	)
	if !output.Success {
		return fmt.Errorf("error in parted: %v\nstdout: %s", output.Error, output.Output)
	}

	if output := Run(`mkfs.fat -F32 "`+LoopDevices[0]+`p1"`, "-F noStdout"); !output.Success {return fmt.Errorf("error in mkfs fat: %v", output.Error)}
	if output := Run(`mkfs.btrfs -f "`+LoopDevices[0]+`p2"`, "-F noStdout"); !output.Success {return fmt.Errorf("error in mkfs btrfs: %v", output.Error)}
	if output := Run(`yes | mkfs.ext4 "`+LoopDevices[0]+`p3"`, "-F noStdout"); !output.Success {return fmt.Errorf("error in mkfs ext4: %v", output.Error)}
	if output := Run(`mkswap "`+LoopDevices[0]+`p4"`, "-F noStdout"); !output.Success {return fmt.Errorf("error in mkswap: %v", output.Error)}

	return nil
}

func MountThePartitons() {
	Mount(LoopDevices[0]+"p2", fp.Join(MntLoc, "/"), "btrfs", "")
	Run("btrfs", "subvolume", "create", fp.Join(MntLoc, "@"), "-F noStdout")
	Umount(MntLoc)
	Mount(LoopDevices[0]+"p2", fp.Join(MntLoc, "/"), "btrfs", "subvol=@")
	Mkdir(fp.Join(MntLoc, "/boot/efi"))
	Mkdir(fp.Join(MntLoc, "/home"))
	Mount(LoopDevices[0]+"p1", fp.Join(MntLoc, "/boot/efi"), "vfat", "")
	Mount(LoopDevices[0]+"p3", fp.Join(MntLoc, "/home"), "ext4", "")
	Run("swapon", LoopDevices[0]+"p4")
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

func MustConatain(t *testing.T) {
	if !IsContainer() {
		t.Skip("Skipping test because it must be run inside a container.")
	}
}

