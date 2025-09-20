package main

import (
	. "Install/lib" //nolint:staticcheck
	"log"
	"os"
	"os/signal"
	fp "path/filepath"
	"syscall"
	. "unix-shell" //nolint:staticcheck
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
    if InChroot() { EscapeChroot(MainRootFD) }
    Run("swapoff", "-a", "-F noStdout")
    Umount(MntLoc)
    if r := recover(); r != nil {
        log.Fatal(r)
    }
}

func install() {
	CloneRepo(userInput.userName)

	if userInput.replaceRepos {
		Cp("etc/*", "/etc/")
	}

	if InChroot() {
		Run(Xargs(ArchPkgsLoc, "pacman", "-Syu", "--noconfirm")...)
		ChrootSetup(userInput.userName, userInput.rootPW, userInput.userPW, userInput.machineName)
		CopyYayCache(userInput.userName, HomeDir)
		ExtraPackages(userInput.userName)
		ConfigSetup(userInput.userName)
		return
	}

	if userInput.cleanInstall {
		Run("pacman", "-Syy", "--noconfirm", "archlinux-keyring", "arch-install-scripts")

		if userInput.autoMount {
			Mount(userInput.part.root, MntLoc, "btrfs", "")
			Cd(MntLoc)
			if !Run("btrfs", "subvolume", "create", "@").Success {CritError()}

			if userInput.part.home == userInput.part.root || userInput.part.home == "" {
				Run("btrfs", "subvolume", "create", "@home")
				Cd("/")
				Umount(MntLoc)
				Mount(userInput.part.root, MntLoc, "btrfs", "subvol=@")
				Mkdir(fp.Join(MntLoc, "/home"))
				Mount(userInput.part.root, MntLoc+"/home", "btrfs", "subvol=@home")
			} else {
				Cd("/")
				Umount(MntLoc)
				Mount(userInput.part.root, MntLoc, "btrfs", "subvol=@")
				Mkdir(fp.Join(MntLoc, "/home"))
				Mount(userInput.part.home, MntLoc+"/home", "", "")
			}

			Mkdir(fp.Join(MntLoc, "/boot/efi"))
			Mount(userInput.part.boot, MntLoc+"/boot/efi", "vfat", "")

			Run("swapoff", "-a", "-F noStdout")
			if userInput.part.swap == "" {
				log.Println("Swap file not yet supported, continuing without swap")
			} else {
				Run("swapon", userInput.part.swap)
			}
		}

		Run(Xargs(ArchPkgsLoc, "pacstrap", "-c", MntLoc)...)
		log.Println("\033[32m\nArch Packages Installed\033[0m")
		Mkdir(fp.Join(MntLoc, "/kcs-reasonable-configs"))
		Cp(RepoLocation+"/*", RepoLocation+"/.*", MntLoc+"/"+RepoName+"/")
		RepoLocation = "/"+RepoName
		escape := Chroot(MntLoc)
		ChrootSetup(userInput.userName, userInput.rootPW, userInput.userPW, userInput.machineName)
		escape()
		CopyYayCache(userInput.userName, fp.Join(MntLoc, HomeDir))
		escape = Chroot(MntLoc)
		ExtraPackages(userInput.userName)
		ConfigSetup(userInput.userName)
		escape()
	} else {
		if AccountExists(userInput.userName) {
			GetAccount(userInput.userName)
		} else {
			CreateAccount(userInput.userName, userInput.userPW)
		}

		Run(Xargs(ArchPkgsLoc, "pacman", "-Syu", "--noconfirm")...)
		CopyYayCache(userInput.userName, HomeDir)
		ExtraPackages(userInput.userName)
		ConfigSetup(userInput.userName)
		Run(RunAs(userInput.userName, "systemctl", "--user", "import-environment")...)
		Run("systemctl", "start", "switch-DEs.service")
	}
}

func getUserInput() {
	userInput.userName = AskUser("Username?: ")
	userInput.machineName = AskUser("Machine name?: ")

	userInput.userPW = AskForPassword(userInput.userName)
	if IsYes(AskUser("Use the same password for root?\n[Y/n]: ")) {
		userInput.rootPW = userInput.userPW
	} else {
		userInput.rootPW = AskForPassword("root")
	}
	userInput.replaceRepos = IsYes(AskUser("Would you like to replace the current systems repos with the recommended repos?\n[Y/n]: "))
	if InChroot() {
		return
	}

	userInput.cleanInstall = IsYes(AskUser("Install to a new location?\n[Y/n]: "))
	if userInput.cleanInstall {
		userInput.autoMount = IsYes(AskUser("Would you like to auto mount the partitions?\n[Y/n]: "))
		if userInput.autoMount {
			Run("lsblk")
			log.Println("Need the full path to the devices you want to mount")
			log.Println("Bios boot is not supported yet so you'll need a separate partition")
			userInput.part.boot = AskUser("Boot partition: ")
			userInput.part.root = AskUser("Root partition: ")
			log.Println("set to root dev or just empty for btrfs subvol")
			userInput.part.home = AskUser("Home partition: ", true)
			userInput.part.swap = AskUser("Swap partition: ", true)
		}
		return
	}
}

func main() {
	MainRootFD = GetRootFD()
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
		SetupSudoersFile()
		getUserInput()
		install()
		log.Println("\033[32mFinished Installation\033[0m")
	} else {
		CritError("\033[31mNeed to Run as Root\033[0m\n")
		log.Println(recover())
	}
}
