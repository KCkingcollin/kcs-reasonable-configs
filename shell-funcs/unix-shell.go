package unix_shell

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"os/signal"
	"os/user"
	fp "path/filepath"
	"regexp"
	"runtime"
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

func CritError(err ...any) {
	_, fileLoc, lineNum, _ := runtime.Caller(1)
	panic(fmt.Sprintln(append(err, fmt.Sprintf("\033[31m\nCritical Failure On Line: %d In: %s\033[0m", lineNum, fp.Base(fileLoc)))...))
}

func getUserShell() string {
    shell := os.Getenv("SHELL")

	if p, err := exec.LookPath(shell); err == nil {
		return p
	}
	if p, err := exec.LookPath("bash"); err == nil {
		return p
	}
	if p, err := exec.LookPath("zsh"); err == nil {
		return p
	}
	if p, err := exec.LookPath("sh"); err == nil {
		return p
	}

	CritError("We kinda need a shell to run shell commands...")
	return ""
}

type RunFlags struct {
	NoStdout 		bool // disables sending output to the terminal, will still be available with .Output
	EnableStdin 	bool // enables stdin
	TrimSpace		bool // aggressive trim *all* leading/trailing whitespace
	NoTrimNL 		bool // no striping trailing '\n' 
	NoShell 		bool // do not use a shell
}

// Run shell command
func RunShellCommand(flags RunFlags, command ...string) CmdInfo {
	runCmdLock.Lock()
	defer runCmdLock.Unlock()

	var stdoutBuffer bytes.Buffer
	var wg sync.WaitGroup

	cmdline := strings.Join(command, " ")

	runningCmd := strings.Fields(cmdline)[0]
	if _, err := exec.LookPath(runningCmd); err != nil {
		CritError(fmt.Errorf("error: Command %s does not exist", runningCmd))
	}

	var cmd *exec.Cmd
	if flags.NoShell {
		//nolint:gosec
		cmd = exec.Command(command[0], command[1:]...)
	} else {
		shell := getUserShell()
		//nolint:gosec
		cmd = exec.Command(shell, "-c", cmdline)
	}

	cmd.Env = os.Environ()

	ptmx, err := pty.Start(cmd)
	if err != nil {
		CritError(fmt.Errorf("failed to start pty: %w", err))
	}

	cmdSigChan := make(chan os.Signal, 1)
	signal.Notify(cmdSigChan, syscall.SIGINT, syscall.SIGTERM)
	wg.Add(1)
	go func() {
		defer wg.Done()
		for sig := range cmdSigChan {
			_ = cmd.Process.Signal(sig)
		}
	}()

	ch := make(chan os.Signal, 1)
	signal.Notify(ch, syscall.SIGWINCH)

	if term.IsTerminal(int(os.Stdin.Fd())) {
		_ = pty.InheritSize(os.Stdin, ptmx)

		go func() {
			for range ch {
				_ = pty.InheritSize(os.Stdin, ptmx)
			}
		}()
	}

	if flags.EnableStdin && term.IsTerminal(int(os.Stdin.Fd())) {
		oldState, err := term.MakeRaw(int(os.Stdin.Fd()))
		if err != nil {
			CritError(err)
		}
		defer func() {_ = term.Restore(int(os.Stdin.Fd()), oldState)}()

		go func() {
			_, _ = io.Copy(ptmx, os.Stdin)
		}()
	}

	wg.Add(1)
	if flags.NoStdout {
		go func () { 
			defer wg.Done()
			_, _ = io.Copy(&stdoutBuffer, ptmx) 
		}()
	} else {
		go func () {
			defer wg.Done()
			_, _ = io.Copy(io.MultiWriter(log.Writer(), &stdoutBuffer), ptmx)
		}()
	}


	err = cmd.Wait()
	if err := ptmx.Close(); err != nil {CritError(err)}
	signal.Stop(cmdSigChan)
	close(cmdSigChan)
	signal.Stop(ch)
	close(ch)
	wg.Wait()

	out := stdoutBuffer.String()
	out = strings.ReplaceAll(out, "\r\n", "\n")
	if !flags.NoTrimNL {
		out = strings.TrimRight(out, "\n")
	}
	if flags.TrimSpace {
		out = strings.TrimSpace(out)
	}

	var cerr error
	if err != nil {
		cerr = fmt.Errorf("%w\n%s", err, out)
	}

	return CmdInfo{
		Success: 	cmd.ProcessState.Success(),
		ExitCode: 	cmd.ProcessState.ExitCode(),
		Output:   	out,
		Error:    	cerr,
	}
}

// run shell command
func Run(command ...string) CmdInfo {
	return RunShellCommand(RunFlags{}, command...)
}

// runs a command with flags
func RunF(flags RunFlags, command ...string) CmdInfo {
	return RunShellCommand(flags, command...)
}

// runs the command with no terminal (stdout) output
func RunS(command ...string) CmdInfo {
	return RunF(RunFlags{NoStdout: true}, command...)
}

// Runs command with piped input
func RunP(flags RunFlags, input string, command ...string) CmdInfo {
	output := []string{"echo", `'`+input+`'`, "|"}
	return RunF(flags, append(output, command...)...)
}

// Runs commands with stdin enabled
func RunI(command ...string) CmdInfo {
	return RunF(RunFlags{EnableStdin: true}, command...)
}

func GetRootFD() *os.File {
	root, err := os.Open("/")
	if err != nil {
		CritError(fmt.Errorf("open root folder: %w", err))
	}
	return root
}

func Chroot(location string) func() {
	oldRoot := GetRootFD()

	dirs := []string{"proc", "dev", "dev/pts", "dev/shm", "run", "tmp", "sys"}
	for _, d := range dirs {
		path := fp.Join(location, d)
		//nolint:gosec
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
            f, _ := os.Create(fp.Clean(dest))
            _ = f.Close()
        }
        Mount(src, dest, "", "bind")
        Mount(src, dest, "", "remount,ro,bind")
    }

    if err := syscall.Chroot(location); err != nil {
        fmt.Fprintln(os.Stderr, fmt.Errorf("failed to chroot: %w", err))
        CritError()
    }
    Cd("/")

    os.Setenv("PATH", "/usr/local/sbin:/usr/local/bin:/usr/bin:/sbin:/bin")

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
			fmt.Fprintln(os.Stderr, fmt.Errorf("failed to chroot back into main root: %w", err))
			CritError()
		}
	} else {
		fmt.Fprintln(os.Stderr, fmt.Errorf("failed to chroot back into the file descriptor %d: %w", oldRootFD.Fd(), err))
		CritError()
	}
	_ = oldRootFD.Close()
}

// sets the egid, euid, and groups to the user's, runs the function, then returns them back to the previous user's
func FuncAs(username string, fn func()) {
    u, err := user.Lookup(username)
    if err != nil {
        CritError(err)
    }

    uid, _ := strconv.Atoi(u.Uid)
    gid, _ := strconv.Atoi(u.Gid)

    groups, _ := u.GroupIds()
    gids := make([]int, len(groups))
    for i, g := range groups {
        gids[i], _ = strconv.Atoi(g)
    }

	origUID := syscall.Geteuid()
	origGID := syscall.Getegid()
	origGroups, _ := syscall.Getgroups()

    if err := syscall.Setgroups(gids); err != nil {
        CritError(err)
    }
    if err := syscall.Setegid(gid); err != nil {
        CritError(err)
    }
    if err := syscall.Seteuid(uid); err != nil {
        CritError(err)
    }

    defer func() {
        _ = syscall.Seteuid(origUID)
        _ = syscall.Setegid(origGID)
		_ = syscall.Setgroups(origGroups)
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

// will panic with any errors
func GetHomeDir(username string) string {
	u, err := user.Lookup(username)
	if err != nil {
		CritError(fmt.Errorf("error looking up user %s: %w", username, err))
	}
	return u.HomeDir
}

func Cd(dir string) error {
	return os.Chdir(dir)
}

func Mv(loc1, loc2 string) error {
	return RunF(RunFlags{NoStdout: true}, "mv", loc1, loc2).Error
}

func Pwd() string {
	currentDir, err := os.Getwd()
	if err != nil {
		CritError(fmt.Printf("Error getting current working directory: %v\n", err))
	}
	return currentDir
}

// the equivalent of -e in a bash if statement
func Find(filename string) bool {
	_, err := os.Stat(filename)
	return !os.IsNotExist(err)
}

func MkFileWithText(text, fileLoc string) {
	Mkdir(fp.Dir(fileLoc))
	//nolint:gosec
	err := os.WriteFile(fp.Clean(fileLoc), []byte(text), 0644)
	if err != nil {
		CritError(fmt.Printf("Error creating file %s: %v\n", fileLoc, err))
	}
}

func AddTextToFile(text, fileLoc string) {
	Mkdir(fp.Dir(fileLoc))
	//nolint:gosec
	file, err := os.OpenFile(fp.Clean(fileLoc), os.O_RDWR|os.O_CREATE|os.O_APPEND, 0644)
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
    data, err := os.ReadFile(fp.Clean(fileLoc))
    if err != nil && !os.IsNotExist(err) {
		CritError(fmt.Printf("Error reading file %s: %v\n", fileLoc, err))
    }

    newData := append([]byte(text), data...)

	// #nosec G306
    err = os.WriteFile(fp.Clean(fileLoc), newData, 0644)
    if err != nil {
		CritError(fmt.Errorf("error prepending to file %s: %w", fileLoc, err))
    }
}

func Rm(fileLoc string) error {
	return os.Remove(fileLoc)
}

// Uses the regular unix copy command, the last arg is the destination
func Cp(input ...string) error {
	return RunF(RunFlags{NoStdout: true}, append([]string{"cp", "-rfp"}, input...)...).Error
}

func Mount(source, target, fstype, options string) {
    var flags uintptr
    fi, err := os.Stat(source)
    if err == nil && !fi.IsDir() && strings.HasPrefix(source, "/dev/") {
        if fstype == "" {
            out := RunF(RunFlags{NoStdout: true}, "blkid", "-o", "value", "-s", "TYPE", source).Output
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
        CritError(fmt.Errorf("mount %s to %s failed: %w", source, target, err))
    }
}

// returns true if the device is mounted
func IsMounted(path string) bool {
	path = fp.Clean(path)
	file, err := os.Open("/proc/mounts")
	if err != nil {
		CritError(fmt.Errorf("failed to open /proc/mounts: %w", err))
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
		CritError(fmt.Errorf("error reading /proc/mounts: %w", err))
	}

	return false
}

// GetMountPoint returns the mount point for a given path or the path if it is a mount point
//
// returns a error only when the path is not found anywhere in /proc/mounts
// all other errors are panicked
func GetMountPoint(path string) (string, error) {
	path = fp.Clean(path)

	file, err := os.Open("/proc/mounts")
	if err != nil {
		CritError(fmt.Errorf("failed to open /proc/mounts: %w", err))
	}
	defer func() {_ = file.Close()}()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		parts := strings.Fields(line)
		if len(parts) > 1 {
			if parts[0] == path {
				return parts[1], nil // device -> mountpoint
			}
			if parts[1] == path {
				return parts[1], nil // mountpoint -> itself
			}
		}
	}

	if err := scanner.Err(); err != nil {
		CritError(fmt.Errorf("error reading /proc/mounts: %w", err))
	}

	return "", fmt.Errorf("error: path is not in /proc/mounts")
}

// unmount a partition
//
// can optionally use a wild card at the end of the string (*) 
// and a best effort attempt at unmounting all the discovered files/dirs will be made
func Umount(target string) {
	var items []string
	if strings.HasSuffix(target, "*") {
		dir := fp.Dir(target)
		prefix := strings.TrimSuffix(fp.Base(target), "*")

		entries, err := os.ReadDir(dir)
		if err != nil {
			CritError(err)
		}

		for _, e := range entries {
			if strings.HasPrefix(e.Name(), prefix) {
				items = append(items, fp.Join(dir, e.Name()))
			}
		}
	} else {
		items = append(items, target)
	}
	for _, item := range items {
		if mountPoint, err := GetMountPoint(item); err == nil {
			if err := syscall.Unmount(mountPoint, syscall.MNT_DETACH); err != nil {
				if err := syscall.Unmount(mountPoint, syscall.MNT_FORCE); err != nil {
					CritError(fmt.Sprintf("Umount %s failed: %v\n", item, err))
				}
			}
		}
	}
}

// basically mkdir -p, can optionally specify the perms, only the first will be used
// will panic the error if it cant make the directory
func Mkdir(dir string, perms ...os.FileMode) {
	if len(perms) == 0 {perms = append(perms, 0755)}
	if err := os.MkdirAll(dir, perms[0]); err != nil {CritError(err)}
}

// limited version of cat, will return nothing in the event of an error
func Cat(path string) string {
	data, err := os.ReadFile(fp.Clean(path))
	if err != nil {
		return  ""
	}
	return string(data)
}
