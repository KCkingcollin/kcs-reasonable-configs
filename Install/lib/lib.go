package lib

import (
	//nolint:staticcheck
	. "unix-shell"
	"bufio"
	"fmt"
	"log"
	"os"
	"os/user"
	fp "path/filepath"
	"regexp"
	"strings"
	"syscall"

	"github.com/go-git/go-git/v5"
	"golang.org/x/term"
)

const (
	RepoName 			= "kcs-reasonable-configs"
	ArchPkgsFileName 	= "arch-packages"
	AurPkgsFileName 	= "aur-packages"
	TempSudoerFile		= "/etc/sudoers.d/tempRule"
)

var (
	HomeDir 		string
	RepoLocation 	string
	ArchPkgsLoc 	string
	AurPkgsLoc 		string
)

func AccountExists(userName string) bool {
	_, err := user.Lookup(userName)
	return err == nil
}

func SetupSudoersFile() {
	if strings.Contains(Cat("/etc/sudoers"), "root") {
		if err := UncommentLine("/etc/sudoers", "#", "root", "ALL=(ALL:ALL)"); err != nil {CritError(err)}
	} else {
		PrependTextToFile("root\tALL=(ALL:ALL) ALL\n", "/etc/sudoers")
	}
	if strings.Contains(Cat("/etc/sudoers"), "@includedir") {
		if err := UncommentLine("/etc/sudoers", "#", "@includedir"); err != nil {CritError(err)}
	} else {
		AddTextToFile("@includedir /etc/sudoers.d\n", "/etc/sudoers")
	}
}

func CopyYayCache(userName, homeLoc string) {
	Mkdir(fp.Join(homeLoc, "/.cache/yay"))
	Cp("/home/*/.cache/yay/*", fp.Join(homeLoc, "/.cache/yay/"))
	Run("chown", "-R", userName+":"+userName, fp.Join(homeLoc, "/.cache/yay"))
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
// first option enables null input
// second option enables hidden input
func AskUser(question string, options ...bool) string {
	var userInput string
	for {
		log.Print(question)
		if len(options) > 1 && options[1] {
			input, _ := term.ReadPassword(0)
			userInput = string(input)
		} else {
			_, _ = fmt.Scanln(&userInput)
		}
		if userInput == "" && (len(options) < 1 || !options[0]) {
			fmt.Println("Cant be empty")
		} else {
			break
		}
	}
	return userInput
}

func AskForPassword(account string) string {
	var pass string
	for {
		pass = AskUser("Set "+account+" password\nPassowrd: ", false, true)
		if pass == AskUser("\nConfirm Passowrd: ", false, true) {
			break
		} else {
			fmt.Println("\nPasswords did not match.")
		}
	}
	log.Println()
	return pass
}

func IsYes(input string) bool {
	match, err := regexp.MatchString(`^[yY]([eE][sS])?$`, input)
	if err != nil {
		CritError(fmt.Printf("Error compiling regex: %v", err))
	}
	return match
}

func CloneRepo(userName string) {
	if HomeDir != "" && Find(HomeDir) {
		if Find(RepoLocation) && !Find(fp.Join(HomeDir, RepoName)) {
			Mv(RepoLocation, fp.Join(HomeDir, RepoName))
		}
		Cd(HomeDir)
	}

	if !Find(RepoLocation) {
		switch {
		case Find(RepoName):
			RepoLocation = fp.Join(Pwd(), RepoName)
		case fp.Base(Pwd()) == RepoName:
			RepoLocation = Pwd()
		case fp.Base(fp.Dir(Pwd())) == RepoName:
			RepoLocation = fp.Dir(Pwd())
		default:
			err := GitClone("https://github.com/KCkingcollin/"+RepoName)
			if err != nil {
				CritError(fmt.Errorf("failed to clone repository: %w", err))
			}
			RepoLocation = fp.Join(Pwd(), RepoName)
		}
	}

	ArchPkgsLoc = fp.Join(RepoLocation, ArchPkgsFileName)
	AurPkgsLoc = fp.Join(RepoLocation, AurPkgsFileName)

	Cd(RepoLocation)

	if fp.Dir(RepoLocation) == HomeDir && userName != "" {
		Run("chown", "-R", userName+":"+userName, ".")
	}
}

// a simple cloning helper function, will work as if you used "git clone" with only the url as the arg
func GitClone(url string) error {
	clonePath := fp.Join(Pwd(), strings.TrimSuffix(fp.Base(url), ".git") )

	log.Println("Cloning repository...")
	_, err := git.PlainClone(clonePath, false, &git.CloneOptions{
		URL:      url,
		Progress: log.Writer(),
	})
	return err
}

// uncomments a line containing at least one of each phrase from a file that uses the prefix for commenting
func UncommentLine(filePath, prefix string, phrases ...string) error {
    file, err := os.Open(fp.Clean(filePath))
    if err != nil {
        return err
    }
	defer file.Close()

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

func CreateAccount(userName, userPW string) {
	Run("useradd", "-m", userName)
	if !RunP(RunFlags{}, userPW+"\n"+userPW, "passwd", userName).Success {CritError()}
	AddUserToSudo(userName)
	HomeDir = GetHomeDir(userName)
}

func GetAccount(userName string) {
	AddUserToSudo(userName)
	HomeDir = GetHomeDir(userName)
}

func CreateSudoUser(userName string) {
	MkFileWithText(userName+"\tALL=(ALL) NOPASSWD: ALL\n", TempSudoerFile)
}

func RemoveSudoUser() {
	err := Rm(TempSudoerFile)
	if err != nil {
		CritError(fmt.Printf("Error removing temp sudoer file: %v", err))
	}
}

// finds all block devices known to /proc/mounts
func FindBlockDevices() []string {
	var mounts []string

	data, err := os.ReadFile("/proc/mounts")
	if err != nil {CritError(err)}

	for line := range strings.SplitSeq(strings.TrimSpace(string(data)), "\n") {
		if strings.HasPrefix(line, "/dev/") {
			mounts = append(mounts, strings.SplitN(line, " ", 2)[0])
		}
	}

	data, err = os.ReadFile("/proc/swaps")
	if err != nil {CritError(err)}

	for line := range strings.SplitSeq(strings.TrimSpace(string(data)), "\n") {
		if strings.HasPrefix(line, "/dev/") {
			mounts = append(mounts, strings.SplitN(line, " ", 2)[0])
		}
	}

	return mounts
}

func CheckAndFixFstab() {
	dev := FindBlockDevices()
	if len(dev) < 1 {
		CritError("Error no devices given")
	}
	for _, elm := range dev {
		out := RunS("blkid", "-s", "UUID", "-o", "value", elm)
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

		//nolint:gosec
		if err := os.WriteFile("/etc/fstab", []byte(strings.Join(lines, "\n")), 0644); err != nil {
			CritError(err)
		}
	}
}

func InstallyayPackages(userName string) {
	Run("chown", "-R", userName+":"+userName, HomeDir)
	if !Run("pacman", "-Q", "|", "grep", "-q", `"yay"`).Success {
		if !Find("yay-bin") {
			Cd(HomeDir)
			FuncAs(userName, func(){_ = GitClone("https://aur.archlinux.org/yay-bin.git")})
		}
		Cd("yay-bin")
		Run(RunAs(userName, "makepkg", "-si", "--noconfirm")...)
		Cd(RepoLocation)
	}
	err := Run(Xargs(AurPkgsLoc, RunAs(userName, "yay", "-Sy", "--noconfirm")...)...).Error 
	if err != nil {
		CritError(err)
	}
}

func ChrootSetup(userName, rootPass, userPW, hostName string) {
	Run("genfstab", "-U", "/", ">>", "/etc/fstab")
	CheckAndFixFstab()

	Run("timedatectl", "set-ntp", "true")
	Run("hwclock", "--systohc")

	MkFileWithText("LANG=en_US.UTF-8", "/etc/locale.conf")
	MkFileWithText("KEYMAP=us", "/etc/vconsole.conf")
	if err := UncommentLine("/etc/locale.gen", "#", "en_US.UTF-8"); err != nil {CritError(err)}
	if err := Run("locale-gen").Error; err != nil {CritError(err)}

	if !RunP(RunFlags{}, rootPass+"\n"+rootPass, "passwd").Success {CritError()}

	Run("systemctl", "enable", "NetworkManager")
	Run("systemctl", "enable", "gdm")
	Run("systemctl", "enable", "cronie")

	Run("pacman", "-Syu", "--noconfirm")

    Run("grub-install", "--target=x86_64-efi", "--efi-directory=/boot/efi", "--bootloader-id=ARCH")
    if !Run("grub-install", "--target=x86_64-efi", "--efi-directory=/boot/efi", "--removable", "--recheck").Success {CritError()}
    if !Run("grub-mkconfig", "-o", "/boot/grub/grub.cfg").Success {CritError()}

	if AccountExists(userName) {
		GetAccount(userName)
	} else {
		CreateAccount(userName, userPW)
	}

	MkFileWithText(hostName, "/etc/hostname")

	Run("chown", "-R", userName+":"+userName, HomeDir)

	log.Println("\033[32m\nChroot Setup Done\033[0m")
}

func ExtraPackages(userName string) {
	CreateSudoUser(userName)
	defer RemoveSudoUser()
	CloneRepo(userName)

	InstallyayPackages(userName)

	Cd(HomeDir)
	if !Find("castle-shell") {
		var err error
		FuncAs(userName, func(){err = GitClone("https://github.com/KCkingcollin/castle-shell")})
		if err != nil {
			CritError("Failed to clone castle shell repo")
		}
	}
	Cd("castle-shell/color-checker")
	Run("go", "env", "-w", "GOFLAGS=-buildvcs=false")
	err := Run("go", "build", "-o", "/usr/bin/color-checker").Error
	if err != nil {
		CritError(err)
	}
	Cd(RepoLocation)

	Run("flatpak", "override", "--filesystem="+fp.Join(HomeDir, ".themes"))
	Run("flatpak", "override", "--filesystem="+fp.Join(HomeDir, ".icons"))
	Run("flatpak", "override", "--filesystem="+fp.Join(HomeDir, ".gtkrc-2.0"))
	Run("flatpak", "override", "--env=GTK_THEME=Adwaita-dark")
	Run("flatpak", "override", "--env=ICON_THEME=Adwaita-dark")

	log.Println("\033[32m\nExtra Packages Installed\033[0m")
}

func ConfigSetup(userName string) {
	CreateSudoUser(userName)
	defer RemoveSudoUser()
	CloneRepo(userName)

	Mv(fp.Join(HomeDir, "/.config/gtk-2.0"), fp.Join(HomeDir, "/.config/gtk-2.0.bak")) 
	Mv(fp.Join(HomeDir, "/.config/gtk-3.0"), fp.Join(HomeDir, "/.config/gtk-3.0.bak")) 
	Mv(fp.Join(HomeDir, "/.config/gtk-4.0"), fp.Join(HomeDir, "/.config/gtk-4.0.bak")) 
    Mv(fp.Join(HomeDir, "/.config/nvim"), fp.Join(HomeDir, "/.config/nvim.bak")) 
    Mv(fp.Join(HomeDir, "/.config/fastfetch"), fp.Join(HomeDir, "/.config/fastfetch.bak")) 
    Mv(fp.Join(HomeDir, "/.config/kitty"), fp.Join(HomeDir, "/.config/kitty.bak")) 
    Mv(fp.Join(HomeDir, "/.config/hypr"), fp.Join(HomeDir, "/.config/hypr.bak")) 
    Mv(fp.Join(HomeDir, "/.config/waybar"), fp.Join(HomeDir, "/.config/waybar.bak")) 
    Mv(fp.Join(HomeDir, "/.config/swaync"), fp.Join(HomeDir, "/.config/swaync.bak")) 
    Mv(fp.Join(HomeDir, "/.config/rofi"), fp.Join(HomeDir, "/.config/rofi.bak")) 
    Mv(fp.Join(HomeDir, "/.config/castle-shell"), fp.Join(HomeDir, "/.config/castle-shell.bak")) 
    Mv(fp.Join(HomeDir, "/.zshrc"), fp.Join(HomeDir, "/.zshrc.bak")) 
    Mv(fp.Join(HomeDir, "/.themes"), fp.Join(HomeDir, "/.themes.bak")) 
    Mv(fp.Join(HomeDir, "/.icons"), fp.Join(HomeDir, "/.icons.bak")) 
    Mv(fp.Join(HomeDir, "/.gtkrc-2.0"), fp.Join(HomeDir, "/.gtkrc-2.0.bak")) 

    Mv("/root/.config/gtk-2.0", "/root/.config/gtk-2.0.bak")
    Mv("/root/.config/gtk-3.0", "/root/.config/gtk-3.0.bak")
    Mv("/root/.config/gtk-4.0", "/root/.config/gtk-4.0.bak")
    Mv("/root/.config/nvim", "/root/.config/nvim.bak") 
    Mv("/root/.config/fastfetch", "/root/.config/fastfetch.bak") 
    Mv("/root/.config/kitty", "/root/.config/kitty.bak") 
    Mv("/root/.config/hypr", "/root/.config/hypr.bak") 
    Mv("/root/.config/waybar", "/root/.config/waybar.bak") 
    Mv("/root/.config/swaync", "/root/.config/swaync.bak") 
    Mv("/root/.config/rofi", "/root/.config/rofi.bak") 
    Mv("/root/.config/castle-shell", "/root/.config/castle-shell.bak") 
    Mv("/root/.zshrc", "/root/.zshrc.bak") 
    Mv("/root/.themes", "/root/.themes.bak") 
    Mv("/root/.icons", "/root/.icons.bak") 
    Mv("/root/.gtkrc-2.0", "/root/.gtkrc-2.0.bak") 

	FuncAs(userName, func(){Mkdir(fp.Join(HomeDir,"/.config"))})
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
	MkFileWithText(userName+"\tALL=(ALL:ALL) NOPASSWD: ALL", "/etc/sudoers.d/AfterInstallRule")

	Run("chsh", "-s", "/bin/zsh", userName)
	Run("chsh", "-s", "/bin/zsh", "root")

	if !Find(HomeDir+"/Pictures/background.jpg") {
		FuncAs(userName, func(){Mkdir(fp.Join(HomeDir, "/Pictures"))})
		Cp("background.jpg", HomeDir+"/Pictures/background.jpg")
	}

	Run("chown", "-R", userName+":"+userName, HomeDir)
	Run("chown", "-R", "root:root", "/root")

	Run("fc-cache", "-rv")

	RunS("rate-mirrors", "--allow-root", "--save", "/etc/pacman.d/mirrorlist", "arch")

	MkFileWithText(
		"[User]\n"+
		"Session=hyprland\n"+
		"XSession=hyprland\n"+
		"Icon="+userName+"/.face\n"+
		"SystemAccount=false\n",
		"/var/lib/AccountsService/users/"+userName, 
	)

	log.Println("\033[32m\nConfigs Installed\033[0m")
}
