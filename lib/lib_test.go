package lib

import (
	"bytes"
	"flag"
	"fmt"
	"io"
	"log"
	"math/rand"
	"os"
	fp "path/filepath"
	"strings"
	"sync"
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

// shellQuoteSingle returns a bash-safe single-quoted literal.
// It closes the quote, inserts an escaped quote, then reopens: '\''
func shellQuoteSingle(s string) string {
    return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

// expects nonquoted string returns printf command with quoted string
func printfLiteral(s string) string {
    quoted := shellQuoteSingle(s)
    if strings.HasPrefix(s, "-") {
        return fmt.Sprintf("printf %%s -- %s", quoted)
    }
    return fmt.Sprintf("printf %%s %s", quoted)
}

func TestRun(t *testing.T) {
	// Curated nasties first.
	cases := []string{
		"",                                     // empty
		"Hello, world!",                        // simple
		"Hello\nworld\n!",                      // newlines
		"\tindented\ttext\t",                   // tabs
		"spaces  in  the  middle",             // multiple spaces
		"trailing space ",                      // trailing space
		" leading space",                       // leading space
		"quotes 'single' and \"double\"",       // quotes
		"backslashes \\\\ and dollars $$ `cmd`",// shell metachar
		"utf8: café 🍩 λ漢字",                    // unicode
		`weird; chars && || () [] {} * ? ~`,    // sh specials
		`%s %d %x not format, just text`,       // printf-looking
	}

	r := rand.New(rand.NewSource(0xC0FFEE))
	const extra = 1000
	for range extra {
		n := 1 + r.Intn(64)
		b := make([]rune, 0, n)
		for len(b) < n {
			x := r.Intn(0x110000)
			switch {
			case x == 0 || x == '\x00':
				continue
			case x < 0x20 && x != '\n' && x != '\t':
				continue
			default:
				b = append(b, rune(x))
			}
		}
		cases = append(cases, string(b))
	}

	for idx, expect := range cases {
		out := Run(printfLiteral(expect), "-F noStdout noTrimNL")
		if !out.Success {
			t.Fatalf("case %d: printf returned non-zero: exit=%d err=%v\ncmdout:\n%s",
				idx, out.ExitCode, out.Error, out.Output)
		}
		if out.Output != expect {
			t.Fatalf("case %d mismatch:\n--- got  (%d bytes) ---\n%q\n--- want (%d bytes) ---\n%q",
				idx, len(out.Output), out.Output, len(expect), expect)
		}
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

	diskNum := MountRawDisk(tempSwapFile)
	if out := Run(`mkswap`, LoopDevices[diskNum], "-F noStdout"); !out.Success {t.Fatal(out.Error, out.Output)}
	if out := Run("swapon", LoopDevices[diskNum], "-F noStdout"); !out.Success {t.Fatal(out.Error, out.Output)}
	defer func() {
		UmountRawDisk(diskNum)
		if err := Rm(tempSwapFile); err != nil {t.Fatal(err)}
	}()

	expected := strings.Split(
		Run(`cat /proc/mounts | grep "^/dev/" | sed 's/^\([^ ]*\).*/\1/'`, "-F noStdout").Output,
		"\n",
	)
	expected = append(
		expected,
		strings.Split(
			Run(`cat /proc/swaps | grep "^/dev/" | sed 's/^\([^ ]*\).*/\1/'`, "-F noStdout").Output,
			"\n",
		)...,
	)
	results := FindBlockDevices()

	if len(expected) < 1 {
		t.Fatal("FindBlockDevices() failed, length of expected results is 0")
	}

	if len(results) != len(expected) {
		t.Fatalf(
			"FindBlockDevices() failed, length of results is %d, expected %d\nExpected output:\n\"%s\"\n\nResulting output:\n\"%s\"", 
			len(results), len(expected), strings.Join(expected, "\n"), strings.Join(results, "\n"),
		)
	}

	for i, result := range results {
		if strings.TrimSpace(result) != strings.TrimSpace(expected[i]) {
			t.Errorf("FindBlockDevices() failed, got \"%s\", want \"%s\"", result, expected[i])
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
	devices := FindBlockDevices()
	for _, dev := range devices {
		data, _ := os.ReadFile("/etc/fstab")
		if strings.Count(string(data), dev) > 1 {
			t.Error("there was more than 1:", dev, "in the fstab")
		}
	}
}

func TestMain(m *testing.M) {
	flag.Parse()
	var output io.Writer
	if *stdoutFlag {
		output = os.Stdout
	} else {
		output = &logBuffer
	}
	log.SetOutput(output)
	MainRootFD = GetRootFD()
	exitCode := m.Run()
	os.Exit(exitCode)
}
