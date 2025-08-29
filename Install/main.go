package main

import (
	"fmt"
	"lib"
	"os"
	"os/signal"
	"syscall"
)

var mainRootFd int

func cleanup() {
	escapeChroot()
	lib.Run("swapoff", "-a")
	lib.Run("umount", "-lf", "/mnt")
}

// change root dir and move there
func chroot(location string) {
	if err := syscall.Chroot(location); err != nil {
		fmt.Fprintln(os.Stderr, fmt.Errorf("failed to chroot: %v", err))
		lib.CritError()
	}
	lib.Cd("/")
}

// undo the chroot
func escapeChroot() {
	if err := syscall.Fchdir(mainRootFd); err != nil {
		fmt.Fprintln(os.Stderr, fmt.Errorf("failed to change dir back to main root: %v", err))
		lib.CritError()
	}
	chroot(".")
}

func install() {
	cleanInstall := lib.AskUser("Clean install arch to a drive?\n[Y/n]: ")
	if lib.IsYes(cleanInstall) {
		lib.CloneRepo()
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

			if !lib.Run("mount", partRoot, "/mnt").ExitCode {lib.CritError()}
			lib.Cd("/mnt")
			if !lib.Run("btrfs", "subvolume", "create", "@").ExitCode {lib.CritError()}

			if partHome == partRoot || partHome == "" {
				lib.Run("btrfs", "subvolume", "create", "@home")
				lib.Cd("/")
				lib.Run("umount", "/mnt")
				if !lib.Run("mount", "-t", "btrfs", "-o", "subvol=@", partRoot, "/mnt").ExitCode {lib.CritError()}
				lib.Run("mkdir", "/mnt/home")
				if !lib.Run("mount", "-t", "btrfs", "-o", "subvol=@home", partRoot, "/mnt/home").ExitCode {lib.CritError()}
			} else {
				lib.Cd("/")
				lib.Run("umount", "/mnt")
				if !lib.Run("mount", "-t", "btrfs", "-o", "subvol=@", partRoot, "/mnt").ExitCode {lib.CritError()}
				lib.Run("mkdir", "/mnt/home")
				if !lib.Run("mount", partHome, "/mnt/home").ExitCode {lib.CritError()}
			}

			lib.Run("mkdir", "-p", "/mnt/boot/efi")
			if !lib.Run("mount", partBoot, "/mnt/boot/efi").ExitCode {lib.CritError()}

			lib.Run("swapoff", "-a")
			if partSwap == "" {
				fmt.Println("Swap file not yet supported, continuing without swap")
			} else {
				lib.Run("swapon", partSwap)
			}
		}
		lib.Run(lib.Xargs(lib.ArchPkgsLoc, "pacstrap", "-c", "/mnt")...)
        fmt.Println("\033[32m\nArch Packages Installed\033[0m")
		lib.Run("mkdir", "/mnt/kcs-reasonable-configs")
		lib.Cp(lib.RepoLocation+"/*", lib.RepoLocation+"/.*", "/mnt/"+lib.RepoName+"/")
		lib.RepoLocation = "/"+lib.RepoName
		chroot("/mnt")
		lib.ChrootSetup(partRoot, partBoot, partHome, partSwap)
		escapeChroot()
		lib.CopyYayCache("/mnt/"+lib.HomeDir)
		chroot("/mnt")
		lib.ExtraPackages()
		lib.ConfigSetup()
		escapeChroot()
	} else {
		if lib.InChroot() {
			partRoot := lib.Run("df", "--output=source,target", "|", "grep", "\"/\"", "|", "head", "-n", "1", "|", "awk", "'{print $1}'").Output
			partBoot := lib.Run("df", "--output=source,target", "|", "grep", "\"/boot\"", "|", "head", "-n", "1", "|", "awk", "'{print $1}'").Output
			partHome := lib.Run("df", "--output=source,target", "|", "grep", "\"/home\"", "|", "head", "-n", "1", "|", "awk", "'{print $1}'").Output

			lib.ChrootSetup(partRoot, partBoot, partHome)
			lib.ExtraPackages()
			lib.ConfigSetup()
		} else {
			createAccount := lib.AskUser("Create a new account?\n[Y/n]: ")
			if lib.IsYes(createAccount) {
				lib.CreateAccount()
			} else {
				lib.GetAccount()
			}
			lib.HomeDir = lib.GetHomeDir(lib.UserName)
			lib.CopyYayCache(lib.HomeDir)
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
		fmt.Fprintln(os.Stderr, fmt.Errorf("open old root: %v", err))
		lib.CritError()
	}
	defer func() {_ = root.Close()}()

	mainRootFd = int(root.Fd())
	
	defer cleanup()
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		cleanup()
		lib.CritError()
	}()

	if os.Geteuid() == 0 {
		install()
		fmt.Println("\033[32mFinished Installation\033[0m")
	} else {
		fmt.Println("\033[31mNeed to Run as Root\033[0m")
		lib.CritError()
	}
}
