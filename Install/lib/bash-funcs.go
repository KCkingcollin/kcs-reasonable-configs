package lib

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"os/user"
	"strings"
)

type ExitAndOutput struct {
	ExitCode 	bool 
	Output 		string
}

// Run bash command
func Run(command ...string) ExitAndOutput {
	cmd := exec.Command("bash", "-c", strings.Join(command, " "))

	var stdoutBuffer bytes.Buffer

	cmd.Stdout = io.MultiWriter(os.Stdout, &stdoutBuffer)
	cmd.Stdin = os.Stdin
	cmd.Stderr = os.Stderr

	err := cmd.Run()

	if err != nil {
		log.Printf("Error: Command '%s' failed: %v\n", command, err)
	}

	commandOutput := ExitAndOutput{cmd.ProcessState.ExitCode() == 0, stdoutBuffer.String()}
	
	return commandOutput
}

// creates a string slice with sudo -S -u username
func RunAs(username string, command ...string) []string {
	output := []string{"sudo", "-S", "-u", username}
	output = append(output, command...)
	return output
}

func Xargs(fileloc string, command ...string) []string {
	output := []string{"xargs", "-a", fileloc}
	output = append(output, command...)
	return output
}

func GetHomeDir(username string) string {
	u, err := user.Lookup(username)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error looking up user %s: %v\n", username, err)
		CritError()
	}
	return u.HomeDir
}

func Cd(dir string) {
	if err := os.Chdir(dir); err != nil {
		fmt.Fprintf(os.Stderr, "Error changing to directory %s: %v\n", dir, err)
		CritError()
	}
}

func Mv(loc1, loc2 string) bool {
	if err := os.Rename(loc1, loc2); err != nil {
		fmt.Fprintf(os.Stderr, "Error moving: %v\n", err)
		return false
	}
	return true
}

func Pwd() string {
	currentDir, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error getting current working directory: %v\n", err)
		CritError()
	}
	return currentDir
}

// the equivalent of -d and -f in a bash if statement
func find(filename string) bool {
	_, err := os.Stat(Pwd()+filename)

	if ! os.IsNotExist(err) {
		return true
	} else if err != nil {
		fmt.Fprintln(os.Stderr, "Error looking for file: ", err)
		CritError()
	}
	return false
}

func MkFileWithText(text, fileLoc string) {
	err := os.WriteFile(fileLoc, []byte(text), 0644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating file %s: %v\n", fileLoc, err)
		CritError()
	}
}

func Rm(fileLoc string) error {
	err := os.Remove(fileLoc)
	if err != nil {
		return fmt.Errorf("error removing file %s: %v", fileLoc, err)
	}
	return nil
}

// Uses the regular unix copy command, the last arg is the destination
func Cp(input ...string) {
	if !Run(append([]string{"cp", "-rfp"}, input...)...).ExitCode {CritError()}
}
