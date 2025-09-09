package lib

import (
	"os"
	fp "path/filepath"
	"strings"
	"testing"
)

func TestRun(t *testing.T) {
	expect := "Hello, world!"
	output := Run("echo", `"Hello, world!"`, "-F noStdout")
	if !output.Success {
		t.Fatal("echo returned non zero:", output.Error)
	}
	if output.Output != expect {
		t.Error("echo returned:", output.Output, "should have been:", expect)
	}

	expect = "Hello\nworld\n!"
	output = Run("echo", "-e", `"Hello\nworld\n!"`, "-F noStdout")
	if !output.Success {
		t.Fatal("echo returned non zero:", output.Error)
	}
	if output.Output != expect {
		t.Error("echo returned:\n", output.Output+"\n", []byte(output.Output), "\n", "should have been:\n", expect+"\n", []byte(expect), "\n")
	}

	output = Run("pacman", "-S", "--noconfirm", "archlinux-keyring", "-F noStdout")
	if !output.Success {
		t.Fatal(output.Output)
	}
}

func TestFindBlockDevices(t *testing.T) {
	// outputs all the block devices in /proc/mounts
	tempSwapFile := "./tempSwap.raw"
	if out := Run(`fallocate -l 1G`, tempSwapFile); !out.Success {t.Fatal(out.Error, out.Output)}

	if out := Run(`parted -s `+tempSwapFile+` mklabel gpt`, "-F noStdout"); !out.Success {t.Fatal(out.Error, out.Output)}
	if out := Run(
		`parted -s `+tempSwapFile+` mkpart primary linux-swap 1MiB 100%`,
		"-F noStdout",
	); !out.Success {t.Fatal(out.Error, out.Output)}

	MountRawDisk(1, tempSwapFile)
	defer UmountRawDisk(1)

	if out := Run(`mkswap`, LoopDevices[1], "-F noStdout"); !out.Success {t.Fatal(out.Error, out.Output)}
	if out := Run("swapon", LoopDevices[1], "-F noStdout"); !out.Success {t.Fatal(out.Error, out.Output)}
	defer func() {
		if out := Run("swapoff", "-a", "-F noStdout"); !out.Success {t.Fatal(out.Error)}
		if err := Rm(tempSwapFile); err != nil {t.Fatal(err)}
	}()

	expected := strings.Split(Run(`cat /proc/mounts | grep "^/dev/" | sed 's/^\([^ ]*\).*/\1/'`, "-F noStdout").Output, "\n")
	expected = append(expected, strings.Split(Run(`cat /proc/swaps | grep "^/dev/" | sed 's/^\([^ ]*\).*/\1/'`, "-F noStdout").Output, "\n")...)
	results := FindBlockDevices()

	if len(expected) < 1 {
		t.Fatal("FindBlockDevices() failed, length of expected results is 0")
	}

	if len(results) != len(expected) {
		t.Fatalf(
			"FindBlockDevices() failed, length of results is %d, expected %d\nExpected output:\n%s\n\nResulting output:\n%s", 
			len(results), len(expected), strings.Join(expected, "\n"), strings.Join(results, "\n"),
		)
	}

	for i, result := range results {
		if strings.TrimSpace(result) != strings.TrimSpace(expected[i]) {
			t.Errorf("FindBlockDevices() failed, got %s, want %s", result, expected[i])
		}
	}
}

func TestCheckAndFixFstab(t *testing.T) {
	tempDir := t.TempDir()

	Mkdir(fp.Join(tempDir, "/etc"))
	Run("genfstab", "-U", "/", ">", fp.Join(tempDir, "/etc/fstab"))
	Run("pacstrap", "-c", tempDir, "util-linux", "bash", "-F noStdout")

	escape := Chroot(tempDir)
	defer escape()

	CheckAndFixFstab()
	devices := []string{
		LoopDevices[0]+"p1",
		LoopDevices[0]+"p2",
		LoopDevices[0]+"p3",
		LoopDevices[0]+"p4",
	}
	for _, dev := range devices {
		data, _ := os.ReadFile("/etc/fstab")
		if strings.Count(string(data), dev) > 1 {
			t.Error("there was more than 1:", dev, "in the fstab")
		}
	}
}

func TestMain(m *testing.M) {
	MntLoc = "/mnt"
	MainRootFD = GetRootFD()
	exitCode := m.Run()
	os.Exit(exitCode)
}
