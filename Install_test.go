package main

import (
	"Install/lib"
	"bytes"
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"testing"
)

var logBuffer safeBuf
var stdoutFlag = flag.Bool("stdout", false, "if the stdout of tests should be visable")

type safeBuf struct {
    mu sync.Mutex
    bytes.Buffer
}

func (b *safeBuf) Write(p []byte) (int, error) {
    b.mu.Lock()
    defer b.mu.Unlock()
    return b.Buffer.Write(p)
}

func (b *safeBuf) Reset() {
    b.mu.Lock()
    defer b.mu.Unlock()
    b.Buffer.Reset()
}

func (b *safeBuf) String() string {
    b.mu.Lock()
    defer b.mu.Unlock()
    return b.Buffer.String()
}

func testCleanup(t testing.TB) {
    t.Helper()

	if lib.InChroot() {
		lib.EscapeChroot(MainRootFD)
	}
    lib.Run("swapoff", "-a")
    lib.Umount(MntLoc)

    if t.Failed() {
        t.Logf("=== logs ===\n%s", logBuffer.String())
    }
}

func TestMountAndInstall(t *testing.T) {
	lib.MustContain(t)
	defer func() {
		if r := recover(); r != nil {
			t.Logf("=== logs (cleanup panic) ===\n%s", logBuffer.String())
			panic(r)
		}
	}()
	logBuffer.Reset()

	diskNum := lib.MountRawDisk(lib.RawDiskLocation)
	t.Cleanup(func(){lib.UmountRawDisk(diskNum)})

	if err := lib.CreatePartitions(diskNum); err != nil {
		t.Fatal(err)
	}

	userInput = options{}
	userInput = options{
		cleanInstall: 	true,
		replaceRepos: 	true,
		autoMount: 		true,
		part: 			partitions{
			boot: 			lib.LoopDevices[diskNum]+"p1",
			root: 			lib.LoopDevices[diskNum]+"p2",
			home: 			lib.LoopDevices[diskNum]+"p3",
			swap: 			lib.LoopDevices[diskNum]+"p4",
		},
		rootPW: 		"testPass",
		userName: 		"testuser",
		userPW: 		"testPass",
		machineName: 	"testev",
	}

	MainRootFD = lib.GetRootFD()
	t.Cleanup(func(){testCleanup(t)})

	lib.SetupSudoersFile()
	install()
}

func TestInstallFromChroot(t *testing.T) {
    defer func() {
        if r := recover(); r != nil {
            t.Logf("=== logs (cleanup panic) ===\n%s", logBuffer.String())
            panic(r)
        }
    }()
	lib.MustContain(t)
	logBuffer.Reset()

	lib.Run("lsblk")
	diskNum := lib.MountRawDisk(lib.RawDiskLocation)
	t.Cleanup(func(){lib.UmountRawDisk(diskNum)})

	if err := lib.CreatePartitions(diskNum); err != nil {
		t.Fatal(err)
	}

	lib.MountThePartitions(diskNum)

	userInput = options{}
	userInput = options{
		replaceRepos: 	true,
		rootPW: 		"testPass",
		userName: 		"testuser",
		userPW: 		"testPass",
		machineName: 	"testev",
	}

	lib.Run("pacstrap", "-c", MntLoc, "base")
	MainRootFD = lib.GetRootFD()

	escape := lib.Chroot(lib.MntLoc)

	t.Cleanup(func(){testCleanup(t)})
	lib.SetupSudoersFile()
	install()

	t.Cleanup(escape)
}

func TestInstallToEnvNewUser(t *testing.T) {
    defer func() {
        if r := recover(); r != nil {
            t.Logf("=== logs (cleanup panic) ===\n%s", logBuffer.String())
            panic(r)
        }
    }()
	lib.MustContain(t)
	logBuffer.Reset()

	userInput = options{}
	userInput = options{
		cleanInstall: 	false,
		replaceRepos: 	true,
		userName: 		"testuser",
		userPW: 		"testPass",
		machineName: 	"testev",
	}

	MainRootFD = lib.GetRootFD()
	t.Cleanup(func(){testCleanup(t)})

	lib.SetupSudoersFile()
	install()
}

func TestInstallToEnvOldUser(t *testing.T) {
    defer func() {
        if r := recover(); r != nil {
            t.Logf("=== logs (cleanup panic) ===\n%s", logBuffer.String())
            panic(r)
        }
    }()
	lib.MustContain(t)
	logBuffer.Reset()

	userInput = options{}
	userInput = options{
		cleanInstall: 	false,
		replaceRepos: 	true,
		userName: 		"arch",
		userPW: 		"testPass",
		machineName: 	"testev",
	}

	MainRootFD = lib.GetRootFD()
	t.Cleanup(func(){testCleanup(t)})

	lib.SetupSudoersFile()
	install()
}

func TestMain(m *testing.M) {
	defer func(){
		for i := range lib.LoopDevices {
			lib.UmountRawDisk(i)
		}
	}()
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func(){
		sig := <-sigChan
		fmt.Println("got a signal")
		if sig != nil {
			fmt.Println("crit")
			lib.CritError("Test was stooped")
		}
	}()
	flag.Parse()
	var output io.Writer
	if *stdoutFlag {
		output = os.Stdout
	} else {
		output = &logBuffer
	}
	log.SetOutput(output)
	lib.RepoLocation = lib.Pwd()
	lib.MntLoc = MntLoc
	exitCode := m.Run()
	os.Exit(exitCode)
}
