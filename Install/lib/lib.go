package lib

import (
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"syscall"
)

const (
	RepoName = "kcs-reasonable-configs"
	ArchPkgsFileName = "arch-packages"
	AurPkgsFileName = "aur-packages"
)

var (
	UserName 		string
	HomeDir 		string
	RepoLocation 	string
	ArchPkgsLoc 	string
	AurPkgsLoc 		string
)

func CritError() {
	panic("\033[31m\nCritical Failure\033[0m")
}

func CopyYayCache(homeDirLoc string) {
	Run("mkdir", "-p", homeDirLoc+"/.cache/yay")
	Cp("/home/*/.cache/yay/*", homeDirLoc+"/.cache/yay/")
}

func InChroot() bool {
	currentDir := Pwd()
	defer Cd(currentDir)
	Cd("/")

	rootStat := syscall.Stat_t{}
	if err := syscall.Stat("/", &rootStat); err != nil {
		return false
	}

	parentStat := syscall.Stat_t{}
	if err := syscall.Stat("../", &parentStat); err != nil {
		return false
	}

	return rootStat.Dev != parentStat.Dev
}

func AskUser(question string, emptyInput ...bool) string {
    fmt.Print(question)
	var userInput string
	if _, err := fmt.Scanln(&userInput); err != nil {CritError()}
	if userInput == "" && (len(emptyInput) > 0 && !emptyInput[0]) {
		fmt.Fprintln(os.Stderr, fmt.Errorf("empty input"))
		CritError()
	}
	return userInput
}

func IsYes(input string) bool {
	match, err := regexp.MatchString(`^[yY]([eE][sS])?$`, input)
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error compiling regex:", err)
		CritError()
	}
	return match
}


func CloneRepo() {
	if UserName != "" {
		HomeDir = GetHomeDir(UserName)
		Cd(HomeDir)
		if !Mv(RepoLocation, HomeDir+"/"+RepoName) {CritError()}
	}

	err := os.Chdir(Pwd()+RepoName)
	if err == nil || filepath.Base(Pwd()) == RepoName {
		RepoLocation = Pwd()
	} else {
		if !Run("git", "clone", "https://github.com/KCkingcollin/"+RepoName).ExitCode {CritError()}
		RepoLocation = RepoName
	}
	ArchPkgsLoc = RepoLocation+"/"+ArchPkgsFileName
	AurPkgsLoc = RepoLocation+"/"+AurPkgsFileName

	Cd(RepoLocation)

	if UserName != "" {
		Run("chown", "-R", UserName+":"+UserName, ".")
	}
}

func AddUserToSudo(username string) {
	Run("groupadd", "sudo")
	Run("usermod", "-aG", "sudo", username)
	Run("sed", "-i", "'/%sudo/ s/^#//'", "/etc/sudoers")
}

func CreateAccount() {
	UserName = AskUser("Name of the account?: ")
	Run("useradd", "-m", UserName)
	if !Run("passwd", UserName).ExitCode {CritError()}
	AddUserToSudo(UserName)
}

func GetAccount() {
	UserName = AskUser(
		"Provid the account user namae you want to set the environment up with\n"+
		"Username?: ", 
	)
	AddUserToSudo(UserName)
}

func CreateSudoUser() {
	MkFileWithText(UserName+"\tALL=(ALL) NOPASSWD: ALL", "/etc/sudoers.d/tempRule")
}

func RemoveSudoUser() {
	err := Rm("/etc/sudoers.d/tmepRule")
	if err != nil {
		fmt.Printf("Error removing temp sudoer file: %v\n", err)
		CritError()
	}
}

func CheckAndFixFstab(dev ...string) {
	if len(dev) < 1 {
		fmt.Printf("Error no devices given")
		CritError()
	}
	for _, elm := range dev {
		Run("sed", "-i", `"/^#/! s|`+elm+`|UUID=$(blkid | grep "`+elm+`" | cut -d'"' -f2)| /etc/fstab"`)
	}
}

func InstallyayPackages() {
	if !Run("pacman", "-Q", "|", "grep", "-q", `"yay"`).ExitCode {
		if !find("yay-bin") {
			if !Run("git", "clone", "https://aur.archlinux.org/yay-bin.git").ExitCode {CritError()}
		}
		Cd("yay-bin")
		Run("chown", "-R", UserName+":"+UserName, ".")
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

	fmt.Println("Set root password")
	Run("passwd")

	Run("systemctl", "enable", "NetworkManager")
	Run("systemctl", "enable", "gdm")
	Run("systemctl", "enable", "cronie")

	Run("pacman", "-Syu", "--noconfirm")

    if !Run("grub-install", "--target=x86_64-efi", "--efi-directory=/boot/efi", "--bootloader-id=ARCH").ExitCode {CritError()}
    if !Run("grub-install", "--target=x86_64-efi", "--efi-directory=/boot/efi", "--removable", "--recheck").ExitCode {CritError()}
    if !Run("grub-mkconfig", "-o", "/boot/grub/grub.cfg").ExitCode {CritError()}

	CreateAccount()

	hostName := AskUser("Name of the machine?: ")
	MkFileWithText(hostName, "/etc/hostname")

	GetHomeDir(UserName)
	Run("chown", "-R", UserName+":"+UserName, HomeDir)

	fmt.Println("\033[32m\nChroot Setup Done\033[0m")
}

func ExtraPackages() {
	CreateSudoUser()
	defer RemoveSudoUser()
	CloneRepo()

	InstallyayPackages()

	if !find("castle-shell") {
		if !Run("git", "clone", "https://github.com/KCkingcollin/castle-shell").ExitCode {CritError()}
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

    Mv(HomeDir+"/.config/nvim", HomeDir+"/.config/nvim.bac") 
    Mv(HomeDir+"/.config/fastfetch", HomeDir+"/.config/fastfetch.bac") 
    Mv(HomeDir+"/.config/kitty", HomeDir+"/.config/foot.bac") 
    Mv(HomeDir+"/.config/hypr", HomeDir+"/.config/hypr.bac") 
    Mv(HomeDir+"/.config/waybar", HomeDir+"/.config/waybar.bac") 
    Mv(HomeDir+"/.config/swaync", HomeDir+"/.config/swaync.bac") 
    Mv(HomeDir+"/.config/rofi", HomeDir+"/.config/rofi.bac") 
    Mv(HomeDir+"/.config/castle-shell", HomeDir+"/.config/castle-shell.bac") 
    Mv(HomeDir+"/.zshrc", HomeDir+"/.zshrc.bac") 
    Mv(HomeDir+"/.themes", HomeDir+"/.themes.bac") 
    Mv(HomeDir+"/.icons", HomeDir+"/.icons.bac") 
    Mv(HomeDir+"/.gtkrc-2.0", HomeDir+"/.gtkrc-2.0.bac") 

    Mv("/root/.config/nvim", "/root/.config/nvim.bac") 
    Mv("/root/.config/fastfetch", "/root/.config/fastfetch.bac") 
    Mv("/root/.config/kitty", "/root/.config/foot.bac") 
    Mv("/root/.config/hypr", "/root/.config/hypr.bac") 
    Mv("/root/.config/waybar", "/root/.config/waybar.bac") 
    Mv("/root/.config/swaync", "/root/.config/swaync.bac") 
    Mv("/root/.config/rofi", "/root/.config/rofi.bac") 
    Mv("/root/.config/castle-shell", "/root/.config/castle-shell.bac") 
    Mv("/root/.zshrc", "/root/.zshrc.bac") 
    Mv("/root/.themes", "/root/.themes.bac") 
    Mv("/root/.icons", "/root/.icons.bac") 
    Mv("/root/.gtkrc-2.0", "/root/.gtkrc-2.0.bac") 

	Run(RunAs(UserName, "mkdir", HomeDir+"/.config")...)
    Cp("config/*", HomeDir+"/.config/")
    Cp("./.zshrc", "./.themes", "./.icons", "./.gtkrc-2.0", HomeDir+"/")
    Mv(HomeDir+"/.config/hypr/hyprland.conf", HomeDir+"/.config/hypr/hyprland.conf.bac")
    Cp("./hyprland.conf.once", HomeDir+"/.config/hypr/hyprland.conf")
	Run("chown", "-R", UserName+":"+UserName, HomeDir)

    Run("mkdir", "/root/.config")
    Cp("config/*", "/root/.config/")
    Cp("etc/*", "/etc/")
    Cp("./.zshrc", "./.themes", "./.icons", "./.gtkrc-2.0", "/root/")
    Cp("./switch-DEs.sh", "/usr/bin/switch-DEs")
    Cp("./theme-check.service", "./waybar-hyprland.service", "/usr/lib/systemd/user/")
    Cp("./switch-DEs.service", "/etc/systemd/system/")
    Run("chown", "-R", "root:root", "/root")

	Cp("AfterInstall.sh", "/bin/")
	MkFileWithText("$UserName\tALL=(ALL:ALL) NOPASSWD: ALL", "/etc/sudoers.d/AfterInstallRule")

	Run("chsh", "-s", "/bin/zsh", UserName)
	Run("chsh", "-s", "/bin/zsh", "root")

	if !find(HomeDir+"/Pictures/background.jpg") {
		RunAs(UserName, "mkdir", "-p", HomeDir+"/Pictures")
		Cp("background.jpg", HomeDir+"/Pictures/background.jpg")
	}

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
