package main

import (
	"Install/lib"
	"log"
	"os"
	"os/signal"
	fp "path/filepath"
	"syscall"
)

const MntLoc = "/mnt"

var (
	userInput 	options
	MainRootFD 	*os.File
)

type partitions struct {
	boot 		string
	root 		string
	home 		string
	swap 		string
}

type options struct {
	cleanInstall 	bool
	replaceRepos 	bool
	autoMount 		bool
	part			partitions
	rootPW 			string
	userName 		string
	userPW			string
	machineName 	string
}

func cleanup() {
    if lib.InChroot() { lib.EscapeChroot(MainRootFD) }
    lib.Run("swapoff", "-a", "-F noStdout")
    lib.Umount(MntLoc)
    if r := recover(); r != nil {
        log.Fatal(r)
    }
}

func install() {
	lib.CloneRepo(userInput.userName)

	if userInput.replaceRepos {
		lib.Cp("etc/*", "/etc/")
	}

	if lib.InChroot() {
		lib.Run(lib.Xargs(lib.ArchPkgsLoc, "pacman", "-Syu", "--noconfirm")...)
		lib.ChrootSetup(userInput.userName, userInput.rootPW, userInput.userPW, userInput.machineName)
		lib.CopyYayCache(userInput.userName, lib.HomeDir)
		lib.ExtraPackages(userInput.userName)
		lib.ConfigSetup(userInput.userName)
		return
	}

	if userInput.cleanInstall {
		lib.Run("pacman", "-Syy", "--noconfirm", "archlinux-keyring", "arch-install-scripts")

		if userInput.autoMount {
			lib.Mount(userInput.part.root, MntLoc, "btrfs", "")
			lib.Cd(MntLoc)
			if !lib.Run("btrfs", "subvolume", "create", "@").Success {lib.CritError()}

			if userInput.part.home == userInput.part.root || userInput.part.home == "" {
				lib.Run("btrfs", "subvolume", "create", "@home")
				lib.Cd("/")
				lib.Umount(MntLoc)
				lib.Mount(userInput.part.root, MntLoc, "btrfs", "subvol=@")
				lib.Mkdir(fp.Join(MntLoc, "/home"))
				lib.Mount(userInput.part.root, MntLoc+"/home", "btrfs", "subvol=@home")
			} else {
				lib.Cd("/")
				lib.Umount(MntLoc)
				lib.Mount(userInput.part.root, MntLoc, "btrfs", "subvol=@")
				lib.Mkdir(fp.Join(MntLoc, "/home"))
				lib.Mount(userInput.part.home, MntLoc+"/home", "", "")
			}

			lib.Mkdir(fp.Join(MntLoc, "/boot/efi"))
			lib.Mount(userInput.part.boot, MntLoc+"/boot/efi", "vfat", "")

			lib.Run("swapoff", "-a", "-F noStdout")
			if userInput.part.swap == "" {
				log.Println("Swap file not yet supported, continuing without swap")
			} else {
				lib.Run("swapon", userInput.part.swap)
			}
		}

		lib.Run(lib.Xargs(lib.ArchPkgsLoc, "pacstrap", "-c", MntLoc)...)
		log.Println("\033[32m\nArch Packages Installed\033[0m")
		lib.Mkdir(fp.Join(MntLoc+"/kcs-reasonable-configs"))
		lib.Cp(lib.RepoLocation+"/*", lib.RepoLocation+"/.*", MntLoc+"/"+lib.RepoName+"/")
		lib.RepoLocation = "/"+lib.RepoName
		escape := lib.Chroot(MntLoc)
		lib.ChrootSetup(userInput.userName, userInput.rootPW, userInput.userPW, userInput.machineName)
		escape()
		lib.CopyYayCache(userInput.userName, fp.Join(MntLoc, lib.HomeDir))
		escape = lib.Chroot(MntLoc)
		lib.ExtraPackages(userInput.userName)
		lib.ConfigSetup(userInput.userName)
		escape()
	} else {
		if lib.AccountExists(userInput.userName) {
			lib.GetAccount(userInput.userName)
		} else {
			lib.CreateAccount(userInput.userName, userInput.userPW)
		}

		lib.Run(lib.Xargs(lib.ArchPkgsLoc, "pacman", "-Syu", "--noconfirm")...)
		lib.CopyYayCache(userInput.userName, lib.HomeDir)
		lib.ExtraPackages(userInput.userName)
		lib.ConfigSetup(userInput.userName)
		lib.Run(lib.RunAs(userInput.userName, "systemctl", "--user", "import-environment")...)
		lib.Run("systemctl", "start", "switch-DEs.service")
	}
}

func getUserInput() {
	userInput.userName = lib.AskUser("Username?: ")
	userInput.machineName = lib.AskUser("Machine name?: ")

	userInput.userPW = lib.AskForPassword(userInput.userName)
	if lib.IsYes(lib.AskUser("Use the same password for root?\n[Y/n]: ")) {
		userInput.rootPW = userInput.userPW
	} else {
		userInput.rootPW = lib.AskForPassword("root")
	}
	userInput.replaceRepos = lib.IsYes(lib.AskUser("Would you like to replace the current systems repos with the recommended repos?\n[Y/n]: "))
	if lib.InChroot() {
		return
	}

	userInput.cleanInstall = lib.IsYes(lib.AskUser("Install to a new location?\n[Y/n]: "))
	if userInput.cleanInstall {
		userInput.autoMount = lib.IsYes(lib.AskUser("Would you like to auto mount the partitions?\n[Y/n]: "))
		if userInput.autoMount {
			lib.Run("lsblk")
			log.Println("Need the full path to the devices you want to mount")
			log.Println("Bios boot is not supported yet so you'll need a separate partition")
			userInput.part.boot = lib.AskUser("Boot partition: ")
			userInput.part.root = lib.AskUser("Root partition: ")
			log.Println("set to root dev or just empty for btrfs subvol")
			userInput.part.home = lib.AskUser("Home partition: ", true)
			userInput.part.swap = lib.AskUser("Swap partition: ", true)
		}
		return
	}
}

func main() {
	MainRootFD = lib.GetRootFD()
	defer cleanup()
	
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		cleanup()
		log.Println("Program Was Closed")
		os.Exit(1)
	}()

	if os.Geteuid() == 0 {
		lib.SetupSudoersFile()
		getUserInput()
		install()
		log.Println("\033[32mFinished Installation\033[0m")
	} else {
		lib.CritError("\033[31mNeed to Run as Root\033[0m\n")
		log.Fatal(recover())
	}
}
