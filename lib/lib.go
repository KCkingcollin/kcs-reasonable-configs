package lib

import (
	"bufio"
	"fmt"
	"os"
	fp "path/filepath"
	"regexp"
	"strings"
	"syscall"
)

const (
	RepoName 			= "kcs-reasonable-configs"
	ArchPkgsFileName 	= "arch-packages"
	AurPkgsFileName 	= "aur-packages"
	TempSudoerFile		= "/etc/sudoers.d/tempRule"
)

var (
	UserName 		string
	HomeDir 		string
	RepoLocation 	string
	ArchPkgsLoc 	string
	AurPkgsLoc 		string
)

func CritError(err ...any) {
	panic(fmt.Sprintln(append(err, "\033[31m\nCritical Failure\033[0m")...))
}

func CopyYayCache(homeLoc string) {
	Mkdir(fp.Join(homeLoc, "/.cache/yay"))
	Cp("/home/*/.cache/yay/*", fp.Join(homeLoc, "/.cache/yay/"), "-F noStderr noStdout")
}

func InChroot() bool {
    hostRoot, err := os.Stat("/proc/1/root")
    if err != nil {
        return false
    }

    currentRoot, err := os.Stat("/")
    if err != nil {
        return false
    }

    hostStat := hostRoot.Sys().(*syscall.Stat_t)
    currentStat := currentRoot.Sys().(*syscall.Stat_t)

    return hostStat.Dev != currentStat.Dev || hostStat.Ino != currentStat.Ino
}

// asks the user the question, and outputs the response
func AskUser(question string, emptyInput ...bool) string {
    fmt.Print(question)
	var userInput string
	if _, err := fmt.Scanln(&userInput); err != nil {CritError(err)}
	if userInput == "" && (len(emptyInput) > 0 && !emptyInput[0]) {
		CritError("Error: empty input")
	}
	return userInput
}

func IsYes(input string) bool {
	match, err := regexp.MatchString(`^[yY]([eE][sS])?$`, input)
	if err != nil {
		CritError(fmt.Printf("Error compiling regex: %v", err))
	}
	return match
}

func CloneRepo() {
	if HomeDir != "" {
		if RepoLocation != "" && find(RepoLocation) {
			if !find(fp.Join(HomeDir, RepoName)) {
				Mv(RepoLocation, fp.Join(HomeDir, RepoName))
			}
		}
		Cd(HomeDir)
	} else {
		Cd("/")
	}

	if find(RepoName) {
		RepoLocation = fp.Join(Pwd(), RepoName)
	} else if fp.Base(Pwd()) == RepoName {
		RepoLocation = Pwd()
	} else {
		if !Run("git", "clone", "https://github.com/KCkingcollin/"+RepoName).Success {CritError()}
		RepoLocation = fp.Join(Pwd(), RepoName)
	}
	ArchPkgsLoc = fp.Join(RepoLocation, ArchPkgsFileName)
	AurPkgsLoc = fp.Join(RepoLocation, AurPkgsFileName)

	Cd(RepoLocation)

	if HomeDir != "" && fp.Base(Pwd()) == RepoName {
		Run("chown", "-R", UserName+":"+UserName, ".")
	}
}

// uncomments a line containing all the phrases from a file that uses the prefix for commenting
func UncommentLine(filePath, prefix string, phrases ...string) error {
    file, err := os.Open(filePath)
    if err != nil {
        return err
    }
	defer func() {_ = file.Close()}()

    var lines []string
    scanner := bufio.NewScanner(file)
    for scanner.Scan() {
        line := scanner.Text()
        matchesAll := true
        for _, phrase := range phrases {
            if !strings.Contains(line, phrase) {
                matchesAll = false
                break
            }
        }

        if matchesAll && strings.HasPrefix(strings.TrimSpace(line), prefix) {
            idx := strings.Index(line, prefix)
            line = line[:idx] + line[idx+1:]
        }

        lines = append(lines, line)
    }
    if err := scanner.Err(); err != nil {
        return err
    }

    outFile, err := os.Create(filePath)
    if err != nil {
        return err
    }
	defer func() {_ = outFile.Close()}()

    for _, line := range lines {
        _, err := fmt.Fprintln(outFile, line)
        if err != nil {
            return err
        }
    }
    return nil
}

func AddUserToSudo(username string) {
	Run("groupadd", "sudo")
	Run("usermod", "-aG", "sudo", username)
	if strings.Contains(Cat("/etc/sudoers"), `%sudo`) {
		if err := UncommentLine("/etc/sudoers", "#", `%sudo`); err != nil {CritError(err)}
	} else {
		PrependTextToFile("%sudo\tALL=(ALL:ALL) ALL\n", "/etc/sudoers")
	}
}

func CreateAccount() {
	UserName = AskUser("Name of the account?: ")
	Run("useradd", "-m", UserName)
	var UserPass string
	for {
		UserPass = AskUser("Set password\nPassowrd: ")
		if UserPass == AskUser("Confirm Passowrd: ") {
			break
		} else {
			fmt.Println("Password did not match.")
		}
	}
	if !RunI(UserPass+"\n"+UserPass, "passwd", UserName).Success {CritError()}
	AddUserToSudo(UserName)
	HomeDir = GetHomeDir(UserName)
}

func GetAccount() {
	UserName = AskUser(
		"Provide the account user name you want to set the environment up with\n"+
		"Username?: ", 
	)
	AddUserToSudo(UserName)
	HomeDir = GetHomeDir(UserName)
}

func CreateSudoUser() {
	MkFileWithText(UserName+"\tALL=(ALL) NOPASSWD: ALL\n", TempSudoerFile)
}

func RemoveSudoUser() {
	err := Rm(TempSudoerFile)
	if err != nil {
		CritError(fmt.Printf("Error removing temp sudoer file: %v", err))
	}
}

func CheckAndFixFstab(dev ...string) {
	if len(dev) < 1 {
		CritError("Error no devices given")
	}
	for _, elm := range dev {
		out := Run("blkid", "-s", "UUID", "-o", "value", elm)
		if !out.Success {
			continue
		}
		uuid := strings.TrimSpace(out.Output)

		data, err := os.ReadFile("/etc/fstab")
		if err != nil { CritError(err) }

		lines := strings.Split(string(data), "\n")
		for i, line := range lines {
			if strings.Contains(line, elm) && !strings.HasPrefix(line, "#") {
				lines[i] = strings.Replace(lines[i], elm, "UUID="+uuid, 1)
			}
		}

		os.WriteFile("/etc/fstab", []byte(strings.Join(lines, "\n")), 0644)
	}
}

func InstallyayPackages() {
	Run("chown", "-R", UserName+":"+UserName, HomeDir)
	if !Run("pacman", "-Q", "|", "grep", "-q", `"yay"`).Success {
		if !find("yay-bin") {
			if !Run(RunAs(UserName, "git", "clone", "https://aur.archlinux.org/yay-bin.git")...).Success {CritError()}
		}
		Cd("yay-bin")
		Run(RunAs(UserName, "makepkg", "-si", "--noconfirm")...)
		Cd("..")
	}
	Run(Xargs(AurPkgsLoc, RunAs(UserName, "yay", "-Sy", "--noconfirm")...)...)
}

func ChrootSetup(dev ...string) {
	Run("genfstab", "-U", "/", ">>", "/etc/fstab")
	CheckAndFixFstab(dev...)

	Run("timedatectl", "set-ntp", "true")
	Run("hwclock", "--systohc")

	MkFileWithText("LANG=en_US.UTF-8", "/etc/locale.conf")
	MkFileWithText("KEYMAP=us", "/etc/vconsole.conf")
	MkFileWithText("en_US.UTF-8 UTF-8", "/etc/locale.gen")
	Run("locale-gen")

	var RootPass string
	for {
		RootPass = AskUser("Set root password\nPassowrd: ")
		if RootPass == AskUser("Confirm Passowrd: ") {
			break
		} else {
			fmt.Println("Password did not match.")
		}
	}
	if !RunI(RootPass+"\n"+RootPass, "passwd").Success {CritError()}

	Run("systemctl", "enable", "NetworkManager")
	Run("systemctl", "enable", "gdm")
	Run("systemctl", "enable", "cronie")

	Run("pacman", "-Syu", "--noconfirm")

    Run("grub-install", "--target=x86_64-efi", "--efi-directory=/boot/efi", "--bootloader-id=ARCH")
    if !Run("grub-install", "--target=x86_64-efi", "--efi-directory=/boot/efi", "--removable", "--recheck").Success {CritError()}
    if !Run("grub-mkconfig", "-o", "/boot/grub/grub.cfg").Success {CritError()}

	CreateAccount()

	hostName := AskUser("Name of the machine?: ")
	MkFileWithText(hostName, "/etc/hostname")

	Run("chown", "-R", UserName+":"+UserName, HomeDir)

	fmt.Println("\033[32m\nChroot Setup Done\033[0m")
}

func ExtraPackages() {
	CreateSudoUser()
	defer RemoveSudoUser()
	CloneRepo()

	InstallyayPackages()

	if !find("castle-shell") {
		if !Run("git", "clone", "https://github.com/KCkingcollin/castle-shell").Success {CritError()}
	}
	Cd("castle-shell/color-checker")
	Run("go", "build", "-o", "/usr/bin/color-checker")
	Cd("../..")

	Run("flatpak", "override", "--filesystem=\"/home/UserName\"/.themes")
	Run("flatpak", "override", "--filesystem=\"/home/UserName\"/.icons")
	Run("flatpak", "override", "--filesystem=\"/home/UserName\"/.gtkrc-2.0")
	Run("flatpak", "override", "--env=GTK_THEME=Adwaita-dark")
	Run("flatpak", "override", "--env=ICON_THEME=Adwaita-dark")

	fmt.Println("\033[32m\nExtra Packages Installed\033[0m")
}

func ConfigSetup() {
	CreateSudoUser()
	defer RemoveSudoUser()
	CloneRepo()

    Mv(fp.Join(HomeDir, "/.config/nvim"), fp.Join(HomeDir, "/.config/nvim.bak")) 
    Mv(fp.Join(HomeDir, "/.config/fastfetch"), fp.Join(HomeDir, "/.config/fastfetch.bak")) 
    Mv(fp.Join(HomeDir, "/.config/kitty"), fp.Join(HomeDir, "/.config/foot.bak")) 
    Mv(fp.Join(HomeDir, "/.config/hypr"), fp.Join(HomeDir, "/.config/hypr.bak")) 
    Mv(fp.Join(HomeDir, "/.config/waybar"), fp.Join(HomeDir, "/.config/waybar.bak")) 
    Mv(fp.Join(HomeDir, "/.config/swaync"), fp.Join(HomeDir, "/.config/swaync.bak")) 
    Mv(fp.Join(HomeDir, "/.config/rofi"), fp.Join(HomeDir, "/.config/rofi.bak")) 
    Mv(fp.Join(HomeDir, "/.config/castle-shell"), fp.Join(HomeDir, "/.config/castle-shell.bak")) 
    Mv(fp.Join(HomeDir, "/.zshrc"), fp.Join(HomeDir, "/.zshrc.bak")) 
    Mv(fp.Join(HomeDir, "/.themes"), fp.Join(HomeDir, "/.themes.bak")) 
    Mv(fp.Join(HomeDir, "/.icons"), fp.Join(HomeDir, "/.icons.bak")) 
    Mv(fp.Join(HomeDir, "/.gtkrc-2.0"), fp.Join(HomeDir, "/.gtkrc-2.0.bak")) 

    Mv("/root/.config/nvim", "/root/.config/nvim.bak") 
    Mv("/root/.config/fastfetch", "/root/.config/fastfetch.bak") 
    Mv("/root/.config/kitty", "/root/.config/foot.bak") 
    Mv("/root/.config/hypr", "/root/.config/hypr.bak") 
    Mv("/root/.config/waybar", "/root/.config/waybar.bak") 
    Mv("/root/.config/swaync", "/root/.config/swaync.bak") 
    Mv("/root/.config/rofi", "/root/.config/rofi.bak") 
    Mv("/root/.config/castle-shell", "/root/.config/castle-shell.bak") 
    Mv("/root/.zshrc", "/root/.zshrc.bak") 
    Mv("/root/.themes", "/root/.themes.bak") 
    Mv("/root/.icons", "/root/.icons.bak") 
    Mv("/root/.gtkrc-2.0", "/root/.gtkrc-2.0.bak") 

	FuncAs(UserName, func(){Mkdir(fp.Join(HomeDir,"/.config"))})
	Cp("config/*", fp.Join(HomeDir, "/.config")+"/")
	Cp("./.zshrc", "./.themes", "./.icons", "./.gtkrc-2.0", HomeDir+"/")
	Mv(fp.Join(HomeDir, "/.config/hypr/hyprland.conf"), fp.Join(HomeDir, "/.config/hypr/hyprland.conf.bak"))
	Cp("./hyprland.conf.once", fp.Join(HomeDir, "/.config/hypr/hyprland.conf"))

	Mkdir("/root/.config")
    Cp("config/*", "/root/.config/")
    Cp("etc/*", "/etc/")
    Cp("./.zshrc", "./.themes", "./.icons", "./.gtkrc-2.0", "/root/")
    Cp("./switch-DEs.sh", "/usr/bin/switch-DEs")
    Cp("./theme-check.service", "./waybar-hyprland.service", "/usr/lib/systemd/user/")
    Cp("./switch-DEs.service", "/etc/systemd/system/")

	Cp("AfterInstall.sh", "/bin/")
	MkFileWithText(UserName+"\tALL=(ALL:ALL) NOPASSWD: ALL", "/etc/sudoers.d/AfterInstallRule")

	Run("chsh", "-s", "/bin/zsh", UserName)
	Run("chsh", "-s", "/bin/zsh", "root")

	if !find(HomeDir+"/Pictures/background.jpg") {
		FuncAs(UserName, func(){Mkdir(fp.Join(HomeDir, "/Pictures"))})
		Cp("background.jpg", HomeDir+"/Pictures/background.jpg")
	}

	Run("chown", "-R", UserName+":"+UserName, HomeDir)
	Run("chown", "-R", "root:root", "/root")

	Run(RunAs(UserName, "gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "\"Adwaita-dark\"")...)
	Run(RunAs(UserName, "gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "\"prefer-dark\"")...)
	Run("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "\"Adwaita-dark\"")
	Run("gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "\"prefer-dark\"")

	Run("rate-mirrors", "--allow-root", "--save", "/etc/pacman.d/mirrorlist", "arch")

	MkFileWithText(
		"[User]\n"+
		"Session=hyprland\n"+
		"XSession=hyprland\n"+
		"Icon="+UserName+"/.face\n"+
		"SystemAccount=false\n",
		"/var/lib/AccountsService/users/"+UserName, 
	)


	fmt.Println("\033[32m\nConfigs Installed\033[0m")
}
