package main

import (
	"Install/lib"
	"fmt"
	"os"
	"os/signal"
	fp "path/filepath"
	"strings"
	"syscall"
)

const MntLoc = "/mnt"

var mainRootFd int

func cleanup() {
	escapeChroot()
	lib.Run("swapoff", "-a", "-F noStderr")
	lib.Umount(MntLoc)
}

func setupSudoersFile() {
	if strings.Contains(lib.Cat("/etc/sudoers"), "root") {
		if err := lib.UncommentLine("/etc/sudoers", "#", "root", "ALL=(ALL:ALL)"); err != nil {lib.CritError(err)}
	} else {
		lib.PrependTextToFile("root\tALL=(ALL:ALL) ALL\n", "/etc/sudoers")
	}
	if strings.Contains(lib.Cat("/etc/sudoers"), "@includedir") {
		if err := lib.UncommentLine("/etc/sudoers", "#", "@includedir"); err != nil {lib.CritError(err)}
	} else {
		lib.AddTextToFile("@includedir /etc/sudoers.d\n", "/etc/sudoers")
	}

}

func chroot(location string) func() {
	dirs := []string{"dev", "dev/pts", "dev/shm", "run", "tmp"}
	for _, d := range dirs {
		path := fp.Join(location, d)
		if err := os.MkdirAll(path, 0755); err != nil {
			fmt.Fprintf(os.Stderr, "failed to create %s: %v\n", path, err)
			lib.CritError()
		}
	}

    _ = syscall.Mount("", "/", "", syscall.MS_PRIVATE|syscall.MS_REC, "")

    lib.Mount("proc", fp.Join(location, "proc"), "proc", "nosuid,noexec,nodev")

    lib.Mount("/sys", fp.Join(location, "sys"), "", "rbind")
    lib.Mount("/sys", fp.Join(location, "sys"), "", "make-rslave")

	lib.Mount("/dev", fp.Join(location, "dev"), "devtmpfs", "")
	lib.Mount("/dev/pts", fp.Join(location, "dev/pts"), "devpts", "")
	lib.Mount("shm", fp.Join(location, "dev/shm"), "tmpfs", "mode=1777,nosuid,nodev")

    lib.Mount("/run", fp.Join(location, "run"), "", "bind,make-private")

	lib.Mount("tmp", fp.Join(location, "tmp"), "tmpfs", "mode=1777,nosuid,nodev,strictatime")

	src, err := fp.EvalSymlinks("/etc/resolv.conf")
    if err == nil {
        dest := fp.Join(location, "etc/resolv.conf")
        if _, err := os.Stat(dest); os.IsNotExist(err) {
            f, _ := os.Create(dest)
            _ = f.Close()
        }
        lib.Mount(src, dest, "", "bind")
        lib.Mount(src, dest, "", "remount,ro,bind")
    }

    if err := syscall.Chroot(location); err != nil {
        fmt.Fprintln(os.Stderr, fmt.Errorf("failed to chroot: %v", err))
        lib.CritError()
    }
    lib.Cd("/")

    _ = os.Setenv("PATH", "/usr/local/sbin:/usr/local/bin:/usr/bin:/sbin:/bin")

	escape := func() {
		escapeChroot()
		lib.Umount(location + "/etc/resolv.conf")
		lib.Umount(location + "/dev/pts")
		lib.Umount(location + "/dev")
		lib.Umount(location + "/sys")
		lib.Umount(location + "/proc")
		lib.Umount(location + "/run")
	}
	return escape
}

func escapeChroot() {
	if err := syscall.Fchdir(mainRootFd); err == nil {
		err := syscall.Chroot(".")
		if err != nil {
			fmt.Fprintln(os.Stderr, fmt.Errorf("failed to chroot back into main root: %v", err))
			lib.CritError()
		}
	} else {
		fmt.Fprintln(os.Stderr, fmt.Errorf("failed to change dir back to main root: %v", err))
		lib.CritError()
	}
}

func install() {
	lib.CloneRepo()
	cleanInstall := lib.AskUser("Clean install arch to a drive?\n[Y/n]: ")
	if lib.IsYes(cleanInstall) {
		replaceRepos := lib.AskUser("Replace current pacman.conf with config's?\n[Y/n]: ")
		if lib.IsYes(replaceRepos) {
			lib.Cp("etc/*", "/etc/")
		}
		lib.Run("pacman", "-Syy", "--noconfirm", "archlinux-keyring", "arch-install-scripts")

		autoMount := lib.AskUser("Auto mount partitions?\n[Y/n]: ")
		var partRoot, partBoot, partHome, partSwap string
		if lib.IsYes(autoMount) {
			lib.Run("lsblk")
			fmt.Println("Need the full path to the devices you want to mount")
			fmt.Println("Bios boot is not supported yet so you'll need a separate partition")
			partBoot = lib.AskUser("Boot partition: ")
			partRoot = lib.AskUser("Root partition: ")
			fmt.Println("set to root dev or just empty for btrfs subvol")
			partHome = lib.AskUser("Home partition: ", true)
			partSwap = lib.AskUser("Swap partition: ", true)

			lib.Mount(partRoot, MntLoc, "btrfs", "")
			lib.Cd(MntLoc)
			if !lib.Run("btrfs", "subvolume", "create", "@").Success {lib.CritError()}

			if partHome == partRoot || partHome == "" {
				lib.Run("btrfs", "subvolume", "create", "@home")
				lib.Cd("/")
				lib.Umount(MntLoc)
				lib.Mount(partRoot, MntLoc, "btrfs", "subvol=@")
				lib.Mkdir(fp.Join(MntLoc, "/home"))
				lib.Mount(partRoot, MntLoc+"/home", "btrfs", "subvol=@home")
			} else {
				lib.Cd("/")
				lib.Umount(MntLoc)
				lib.Mount(partRoot, MntLoc, "btrfs", "subvol=@")
				lib.Mkdir(fp.Join(MntLoc, "/home"))
				lib.Mount(partHome, MntLoc+"/home", "", "")
			}

			lib.Mkdir(fp.Join(MntLoc, "/boot/efi"))
			lib.Mount(partBoot, MntLoc+"/boot/efi", "vfat", "")

			lib.Run("swapoff", "-a", "-F noStderr")
			if partSwap == "" {
				fmt.Println("Swap file not yet supported, continuing without swap")
			} else {
				lib.Run("swapon", partSwap)
			}
		}

		lib.Run(lib.Xargs(lib.ArchPkgsLoc, "pacstrap", "-c", MntLoc)...)
        fmt.Println("\033[32m\nArch Packages Installed\033[0m")
		lib.Mkdir(fp.Join(MntLoc+"/kcs-reasonable-configs"))
		lib.Cp(lib.RepoLocation+"/*", lib.RepoLocation+"/.*", MntLoc+"/"+lib.RepoName+"/")
		lib.RepoLocation = "/"+lib.RepoName
		escape := chroot(MntLoc)
		lib.ChrootSetup(partRoot, partBoot, partHome, partSwap)
		escape()
		lib.CopyYayCache(fp.Join(MntLoc, lib.HomeDir))
		escape = chroot(MntLoc)
		lib.ExtraPackages()
		lib.ConfigSetup()
		escape()
	} else {
		if lib.InChroot() {
			partRoot := lib.Run("df", "--output=source,target", "|", "grep", "\"/\"", "|", "head", "-n", "1", "|", "awk", "'{print $1}'").Output
			partBoot := lib.Run("df", "--output=source,target", "|", "grep", "\"/boot\"", "|", "head", "-n", "1", "|", "awk", "'{print $1}'").Output
			partHome := lib.Run("df", "--output=source,target", "|", "grep", "\"/home\"", "|", "head", "-n", "1", "|", "awk", "'{print $1}'").Output

			lib.Run(lib.Xargs(lib.ArchPkgsLoc, "pacman", "-Syu", "--noconfirm")...)
			lib.ChrootSetup(partRoot, partBoot, partHome)
			lib.FuncAs(lib.UserName, func(){lib.CopyYayCache(lib.HomeDir)})
			lib.ExtraPackages()
			lib.ConfigSetup()
		} else {
			createAccount := lib.AskUser("Create a new account?\n[Y/n]: ")
			if lib.IsYes(createAccount) {
				lib.CreateAccount()
			} else {
				lib.GetAccount()
			}

			lib.Run(lib.Xargs(lib.ArchPkgsLoc, "pacman", "-Syu", "--noconfirm")...)
			lib.FuncAs(lib.UserName, func(){lib.CopyYayCache(lib.HomeDir)})
			lib.ExtraPackages()
			lib.ConfigSetup()
			lib.Run(lib.RunAs(lib.UserName, "systemctl", "--user", "import-environment")...)
			lib.Run("systemctl", "start", "switch-DEs.service")
		}
	}
}

func main() {
	root, err := os.Open("/")
	if err != nil {
		lib.CritError(fmt.Errorf("open root folder: %v", err))
	}
	defer func() {_ = root.Close()}()

	mainRootFd = int(root.Fd())
	
	defer cleanup()
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		cleanup()
		fmt.Println("Program Was Closed")
		os.Exit(1)
	}()

	if os.Geteuid() == 0 {
		setupSudoersFile()
		install()
		fmt.Println("\033[32mFinished Installation\033[0m")
	} else {
		lib.CritError("\033[31mNeed to Run as Root\033[0m\n")
	}
}
