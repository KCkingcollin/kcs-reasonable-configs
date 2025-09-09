package lib

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/user"
	fp "path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"syscall"

	"github.com/creack/pty"
	"golang.org/x/term"
)

var (
	runCmdLock sync.Mutex
)

type CmdInfo struct {
	Success 	bool
	ExitCode 	int 
	Output 		string
	Error 		error
}

// Run bash command
// Use -F followed by space separated flags at the end of the command
// flag 1: noStdout
// flag 2: noStderr
// flag 3: enableStdin
func Run(command ...string) CmdInfo {
	runCmdLock.Lock()
	defer runCmdLock.Unlock()

	var flags string
	if strings.Contains(command[len(command)-1], "-F") {
		flags = command[len(command)-1]
		command = command[:len(command)-1]
	}

	if !find("/bin/bash") {
		CritError("We kinda need bash for this")
	}

	cmd := exec.Command("bash", "-c", strings.Join(command, " "))

	if strings.Contains(flags, "enableStdin") {
		cmd.Stdin = os.Stdin
	}

	// something about pty freezes in an environment without a bin folder
	ptmx, err := pty.Start(cmd)
	if err != nil {
		return CmdInfo{false, 1, "", fmt.Errorf("failed to start pty: %v", err)}
	}
	defer func() {_ = ptmx.Close()}()

	if term.IsTerminal(int(os.Stdin.Fd())) {
		_ = pty.InheritSize(os.Stdin, ptmx)
	}

	var stdoutBuffer, stderrBuffer bytes.Buffer

	if strings.Contains(flags, "noStderr") {
		cmd.Stderr = &stderrBuffer
	} else {
		cmd.Stderr = io.MultiWriter(os.Stderr, &stderrBuffer)
	}

	if strings.Contains(flags, "noStdout") {
		go func () { _, _ = io.Copy(&stdoutBuffer, ptmx) }()
	} else {
		go func () { _, _ = io.Copy(io.MultiWriter(os.Stdout, &stdoutBuffer), ptmx) }()
	}

	err = cmd.Wait()
	return CmdInfo{
		Success: 	cmd.ProcessState.Success(),
		ExitCode: 	cmd.ProcessState.ExitCode(),
		Output:   	strings.ReplaceAll(strings.TrimSpace(stdoutBuffer.String()), "\r\n", "\n"),
		Error:    	fmt.Errorf("%v%s", err, stderrBuffer.String()),
	}
}

func GetRootFD() *os.File {
	root, err := os.Open("/")
	if err != nil {
		CritError(fmt.Errorf("open root folder: %v", err))
	}
	return root
}

func Chroot(location string) func() {
	oldRoot := GetRootFD()

	dirs := []string{"proc", "dev", "dev/pts", "dev/shm", "run", "tmp", "sys"}
	for _, d := range dirs {
		path := fp.Join(location, d)
		if err := os.MkdirAll(path, 0755); err != nil {
			fmt.Fprintf(os.Stderr, "failed to create %s: %v\n", path, err)
			CritError()
		}
	}

    _ = syscall.Mount("", "/", "", syscall.MS_PRIVATE|syscall.MS_REC, "")

    Mount("proc", fp.Join(location, "proc"), "proc", "nosuid,noexec,nodev")

    Mount("/sys", fp.Join(location, "sys"), "", "rbind")
    Mount("/sys", fp.Join(location, "sys"), "", "make-rslave")

	Mount("/dev", fp.Join(location, "dev"), "devtmpfs", "")
	Mount("/dev/pts", fp.Join(location, "dev/pts"), "devpts", "")
	Mount("shm", fp.Join(location, "dev/shm"), "tmpfs", "mode=1777,nosuid,nodev")

    Mount("/run", fp.Join(location, "run"), "", "bind,make-private")

	Mount("tmp", fp.Join(location, "tmp"), "tmpfs", "mode=1777,nosuid,nodev,strictatime")

	src, err := fp.EvalSymlinks("/etc/resolv.conf")
    if err == nil {
        dest := fp.Join(location, "etc/resolv.conf")
        if _, err := os.Stat(dest); os.IsNotExist(err) {
            f, _ := os.Create(dest)
            _ = f.Close()
        }
        Mount(src, dest, "", "bind")
        Mount(src, dest, "", "remount,ro,bind")
    }

    if err := syscall.Chroot(location); err != nil {
        fmt.Fprintln(os.Stderr, fmt.Errorf("failed to chroot: %v", err))
        CritError()
    }
    Cd("/")

    _ = os.Setenv("PATH", "/usr/local/sbin:/usr/local/bin:/usr/bin:/sbin:/bin")

	escape := func() {
		EscapeChroot(oldRoot)
		Umount(fp.Join(location, "/etc/resolv.conf"))
		for _, d := range dirs {
			path := fp.Join(location, d)
			Umount(path)
		}
		_ = oldRoot.Close()
	}
	return escape
}

func EscapeChroot(oldRootFD *os.File) {
	if err := syscall.Fchdir(int(oldRootFD.Fd())); err == nil {
		err := syscall.Chroot(".")
		if err != nil {
			fmt.Fprintln(os.Stderr, fmt.Errorf("failed to chroot back into main root: %v", err))
			CritError()
		}
	} else {
		fmt.Fprintln(os.Stderr, fmt.Errorf("failed to chroot back into the file descriptor %d: %v", oldRootFD.Fd(), err))
		CritError()
	}
	_ = oldRootFD.Close()
}

// Runs command with input
func RunI(input string, command ...string) CmdInfo {
	output := []string{"echo", `'`+input+`'`, "|"}
	return Run(append(output, command...)...)
}

// Sets the current user, and returns a function to set it back and a error
func FuncAs(username string, fn func()) {
	u, err := user.Lookup(username)
	if err != nil {
		CritError(err)
	}

	uid, _ := strconv.Atoi(u.Uid)
	gid, _ := strconv.Atoi(u.Gid)

	origUID := syscall.Geteuid()
	origGID := syscall.Getegid()

	if err := syscall.Setegid(gid); err != nil {
		CritError(err)
	}
	if err := syscall.Seteuid(uid); err != nil {
		CritError(err)
	}

	defer func() {
		if err := syscall.Seteuid(origUID); err != nil {
			CritError(err)
		}
		if err := syscall.Setegid(origGID); err != nil {
			CritError(err)
		}
	}()

	fn()
}

// Appends sudo -S -u username to the beginning of the command
func RunAs(username string, command ...string) []string {
	return append([]string{"sudo", "-S", "-u", username}, command...)
}

// Wrapper for xargs -a, returns a string slice
func Xargs(fileloc string, command ...string) []string {
	output := []string{"xargs", "-a", fileloc}
	return append(output, command...)
}

func GetHomeDir(username string) string {
	u, err := user.Lookup(username)
	if err != nil {
		CritError(fmt.Printf("Error looking up user %s: %v", username, err))
	}
	return u.HomeDir
}

func Cd(dir string) {
	if err := os.Chdir(dir); err != nil {
		CritError(fmt.Printf("Error changing to directory %s: %v", dir, err))
	}
}

func Mv(loc1, loc2 string) CmdInfo {
	return Run("mv", loc1, loc2, "-F noStdout noStderr")
}

func Pwd() string {
	currentDir, err := os.Getwd()
	if err != nil {
		CritError(fmt.Printf("Error getting current working directory: %v\n", err))
	}
	return currentDir
}

// the equivalent of -e in a bash if statement
func find(filename string) bool {
	_, err := os.Stat(filename)
	return !os.IsNotExist(err)
}

func MkFileWithText(text, fileLoc string) {
	Mkdir(fp.Dir(fileLoc))
	err := os.WriteFile(fileLoc, []byte(text), 0644)
	if err != nil {
		CritError(fmt.Printf("Error creating file %s: %v\n", fileLoc, err))
	}
}

func AddTextToFile(text, fileLoc string) {
	Mkdir(fp.Dir(fileLoc))
	file, err := os.OpenFile(fileLoc, os.O_RDWR|os.O_CREATE|os.O_APPEND, 0644)
	if err != nil {
		CritError(fmt.Printf("Error opening file %s: %v\n", fileLoc, err))
	}
	defer func(){_ = file.Close()}()
	_, err = file.WriteString(text)
	if err != nil {
		CritError(fmt.Printf("Error appending to file %s: %v\n", fileLoc, err))
	}
}

func PrependTextToFile(text, fileLoc string) {
    data, err := os.ReadFile(fileLoc)
    if err != nil && !os.IsNotExist(err) {
		CritError(fmt.Printf("Error reading file %s: %v\n", fileLoc, err))
    }

    newData := append([]byte(text), data...)

    err = os.WriteFile(fileLoc, newData, 0644)
    if err != nil {
		CritError(fmt.Printf("Error prepending to file %s: %v\n", fileLoc, err))
    }
}

func Rm(fileLoc string) error {
	err := os.Remove(fileLoc)
	if err != nil {
		return fmt.Errorf("error removing file %s: %v", fileLoc, err)
	}
	return nil
}

// Uses the regular unix copy command, the last arg is the destination, unless -F is used for a flag
func Cp(input ...string) CmdInfo {
	return Run(append([]string{"cp", "-rfp"}, input...)...)
}

func IsMounted(path string) bool {
	file, err := os.Open("/proc/mounts")
	if err != nil {
		fmt.Fprintln(os.Stderr, fmt.Errorf("failed to open /proc/mounts: %w", err))
		return false
	}
	defer func() {_ = file.Close()}()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.Fields(line)
		if len(parts) >= 2 {
			if parts[0] == path || parts[1] == path {
				return true
			}
		}
	}

	if err := scanner.Err(); err != nil {
		fmt.Fprintln(os.Stderr, fmt.Errorf("error reading /proc/mounts: %w", err))
		return false
	}

	return false
}

func Mount(source, target, fstype, options string) {
    var flags uintptr
    fi, err := os.Stat(source)
    if err == nil && !fi.IsDir() && strings.HasPrefix(source, "/dev/") {
        if fstype == "" {
            out := Run("blkid", "-o", "value", "-s", "TYPE", source).Output
            fstype = strings.TrimSpace(out)
            if fstype == "" {
                CritError(fmt.Errorf("could not detect fstype for %s", source))
            }
        }
    }

	if opt := "rbind"; strings.Contains(options, opt) {
        flags |= syscall.MS_BIND | syscall.MS_REC
        options = strings.ReplaceAll(options, opt, "")
    }
	if opt := "bind"; strings.Contains(options, opt) {
        flags |= syscall.MS_BIND
        options = strings.ReplaceAll(options, opt, "")
    }
	if opt := "remount"; strings.Contains(options, opt) {
        flags |= syscall.MS_REMOUNT
        options = strings.ReplaceAll(options, opt, "")
    }
	if opt := "make-rslave"; strings.Contains(options, opt) {
        flags |= syscall.MS_SLAVE
        options = strings.ReplaceAll(options, opt, "")
    }
	if opt := "make-rprivate"; strings.Contains(options, opt) {
        flags |= syscall.MS_PRIVATE
        options = strings.ReplaceAll(options, opt, "")
    }
	if opt := "make-rshared"; strings.Contains(options, opt) {
        flags |= syscall.MS_SHARED
        options = strings.ReplaceAll(options, opt, "")
    }
	if opt := "nosuid"; strings.Contains(options, opt) {
        flags |= syscall.MS_NOSUID
        options = strings.ReplaceAll(options, opt, "")
    }
	if opt := "noexec"; strings.Contains(options, opt) {
        flags |= syscall.MS_NOEXEC
        options = strings.ReplaceAll(options, opt, "")
    }
	if opt := "nodev"; strings.Contains(options, opt) {
        flags |= syscall.MS_NODEV
        options = strings.ReplaceAll(options, opt, "")
    }
	if opt := "strictatime"; strings.Contains(options, opt) {
        flags |= syscall.MS_STRICTATIME
        options = strings.ReplaceAll(options, opt, "")
    }

    re := regexp.MustCompile(",+")
    options = re.ReplaceAllString(options, ",")
    options = strings.Trim(options, ",")

    data := options
    if flags&syscall.MS_BIND != 0 {
        data = ""
    }

    if err := syscall.Mount(source, target, fstype, flags, data); err != nil {
        CritError(fmt.Errorf("mount %s to %s failed: %v", source, target, err))
    }
}

func Umount(target string) {
	if IsMounted(target) {
		if err := syscall.Unmount(target, syscall.MNT_DETACH); err != nil {
			if err := syscall.Unmount(target, syscall.MNT_FORCE); err != nil {
				CritError(fmt.Printf("Umount %s failed: %v\n", target, err))
			}
		}
	}
}

// basically mkdir -p, can optionally specify the perms, only the first will be used
func Mkdir(dir string, perms ...os.FileMode) {
	if len(perms) == 0 {perms = append(perms, 0755)}
	if err := os.MkdirAll(dir, perms[0]); err != nil {CritError(err)}
}

func Cat(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		CritError(err)
	}
	return string(data)
}
