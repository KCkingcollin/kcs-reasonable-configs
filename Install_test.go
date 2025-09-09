package main

import (
	"Install/lib"
	"os"
	"testing"
)

func TestMountAndInstall(t *testing.T) {
	lib.MustConatain(t)
	if err := lib.CreatePartitions(); err != nil {
		t.Fatal(err)
	}

	lib.MountRawDisk(0, lib.RawDiskLocation)
	defer lib.UmountRawDisk(0)

	testInput = true
	userInput = options{
		cleanInstall: 	true,
		replaceRepos: 	true,
		autoMount: 		true,
		part: 			partitions{
			boot: 			lib.LoopDevices[0]+"p1",
			root: 			lib.LoopDevices[0]+"p2",
			home: 			lib.LoopDevices[0]+"p3",
			swap: 			lib.LoopDevices[0]+"p4",
		},
		rootPW: 		"testPass",
		userName: 		"testuser",
		userPW: 		"testPass",
		machineName: 	"testev",
	}

	main()
}

// func TestInstallFromChroot(t *testing.T) {
// 	lib.MustConatain(t)
// 	if err := lib.CreatePartitions(); err != nil {
// 		t.Fatal(err)
// 	}
//
// 	lib.MountRawDisk(0, lib.RawDiskLocation)
// 	defer lib.UmountRawDisk(0)
//
// 	lib.MountThePartitons()
//
// 	testInput = true
// 	userInput = options{
// 		replaceRepos: 	true,
// 		rootPW: 		"testPass",
// 		userName: 		"testuser",
// 		userPW: 		"testPass",
// 		machineName: 	"testev",
// 	}
//
// 	escape := lib.Chroot(lib.MntLoc)
// 	defer escape()
// 	main()
// }

func TestMain(m *testing.M) {
	defer func(){
		lib.UmountRawDisk(0)
	}()
	lib.MntLoc = "/mnt"
	exitCode := m.Run()
	lib.UmountRawDisk(0)
	os.Exit(exitCode)
}
