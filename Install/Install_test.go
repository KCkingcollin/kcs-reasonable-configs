package main

import (
	. "Install/lib"
	. "unix-shell"
	at "auto-testing/lib"
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

	if InChroot() {
		EscapeChroot(MainRootFD)
	}
    Run("swapoff", "-a")
    Umount(MntLoc)

    if t.Failed() {
        t.Logf("=== logs ===\n%s", logBuffer.String())
    }
}

func TestMountAndInstall(t *testing.T) {
	at.MustContain(t)
	defer func() {
		if r := recover(); r != nil {
			t.Logf("=== logs (cleanup panic) ===\n%s", logBuffer.String())
			panic(r)
		}
	}()
	logBuffer.Reset()

	diskNum := at.MountRawDisk(at.RawDiskLocation)
	t.Cleanup(func(){at.UmountRawDisk(diskNum)})

	if err := at.CreatePartitions(diskNum); err != nil {
		t.Fatal(err)
	}

	userInput = options{}
	userInput = options{
		cleanInstall: 	true,
		replaceRepos: 	true,
		autoMount: 		true,
		part: 			partitions{
			boot: 			at.LoopDevices[diskNum]+"p1",
			root: 			at.LoopDevices[diskNum]+"p2",
			home: 			at.LoopDevices[diskNum]+"p3",
			swap: 			at.LoopDevices[diskNum]+"p4",
		},
		rootPW: 		"testPass",
		userName: 		"testuser",
		userPW: 		"testPass",
		machineName: 	"testev",
	}

	MainRootFD = GetRootFD()
	t.Cleanup(func(){testCleanup(t)})

	SetupSudoersFile()
	install()
}

func TestInstallFromChroot(t *testing.T) {
	at.MustContain(t)
	defer func() {
		if r := recover(); r != nil {
			t.Logf("=== logs (cleanup panic) ===\n%s", logBuffer.String())
			panic(r)
		}
	}()
	logBuffer.Reset()

	diskNum := at.MountRawDisk(at.RawDiskLocation)
	t.Cleanup(func(){at.UmountRawDisk(diskNum)})

	if err := at.CreatePartitions(diskNum); err != nil {
		t.Fatal(err)
	}

	TestUserName := "testuser"
	at.MountThePartitions(diskNum, MntLoc, TestUserName)

	userInput = options{}
	userInput = options{
		replaceRepos: 	true,
		rootPW: 		"testPass",
		userName: 		TestUserName,
		userPW: 		"testPass",
		machineName: 	"testev",
	}

	Run("pacstrap", "-c", MntLoc, "base")
	MainRootFD = GetRootFD()

	escape := Chroot(MntLoc)

	t.Cleanup(func(){testCleanup(t)})
	SetupSudoersFile()
	install()

	t.Cleanup(escape)
}

func TestInstallToEnvNewUser(t *testing.T) {
	at.MustContain(t)
	defer func() {
		if r := recover(); r != nil {
			t.Logf("=== logs (cleanup panic) ===\n%s", logBuffer.String())
			panic(r)
		}
	}()
	logBuffer.Reset()

	userInput = options{}
	userInput = options{
		cleanInstall: 	false,
		replaceRepos: 	true,
		userName: 		"testuser",
		userPW: 		"testPass",
		machineName: 	"testev",
	}

	MainRootFD = GetRootFD()
	t.Cleanup(func(){testCleanup(t)})

	SetupSudoersFile()
	install()
}

func TestInstallToEnvOldUser(t *testing.T) {
	at.MustContain(t)
	defer func() {
		if r := recover(); r != nil {
			t.Logf("=== logs (cleanup panic) ===\n%s", logBuffer.String())
			panic(r)
		}
	}()
	logBuffer.Reset()

	userInput = options{}
	userInput = options{
		cleanInstall: 	false,
		replaceRepos: 	true,
		userName: 		"arch",
		userPW: 		"testPass",
		machineName: 	"testev",
	}

	MainRootFD = GetRootFD()
	t.Cleanup(func(){testCleanup(t)})

	SetupSudoersFile()
	install()
}

func startup(m *testing.M) int {
	defer func(){
		for i := range at.LoopDevices {
			at.UmountRawDisk(i)
		}
	}()
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func(){
		sig := <-sigChan
		fmt.Println("got a signal")
		if sig != nil {
			fmt.Println("crit")
			CritError("Test was stooped")
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
	return m.Run()
}

func TestMain(m *testing.M) {
	os.Exit(startup(m))
}
