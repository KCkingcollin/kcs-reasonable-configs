package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	"strings"

	lib "Install/lib"

	podImages "github.com/containers/podman/v5/pkg/bindings/images"
	libvirt "libvirt.org/go/libvirt"
)

const installTestFile = "Install_test.go"

var errTestFailed = errors.New("")

func main() {
	if os.Geteuid() != 0 {
		fmt.Println("needs to be run as root")
		os.Exit(1)
	}
	if !lib.Find("Install.go") {
		if lib.Find("../Install.go") {
			lib.Cd("..")
		} else {
			fmt.Println("Needs to be run in the repo location")
			os.Exit(1)
		}
	}

	newCtx := context.Background()
	if len(os.Args) < 1 {
		fmt.Fprintf(os.Stderr, "usage: %s {unit|system} [args]\n", os.Args[0])
		os.Exit(2)
	}
	podmanCtx, err := podmanConn(newCtx)
	if err != nil {
		log.Fatalln("Big failure in getting the podman connection")
	}

	mode := os.Args[1]
	switch mode {
	case "unit":
		if err := unitTest(podmanCtx, os.Args[2:]); err != nil {
			log.Fatalf("\x1b[31m[ FAIL ]\x1b[0m\n%v\n", err)
		}
		fmt.Printf("\x1b[32m[ PASS ]\x1b[0m\n")
	case "system":
		if err := systemTests(podmanCtx, os.Args[2:]); err != nil {
			log.Fatalf("\x1b[31m[ FAIL ]\x1b[0m\n%v\n", err)
		}
		fmt.Printf("\x1b[32m[ PASS ]\x1b[0m\n")
	case "help":
		fmt.Fprintf(os.Stderr, "usage: %s {unit|system} [args]\n", os.Args[0])
		os.Exit(2)
	default:
		if err := unitTest(podmanCtx, os.Args[1:]); err != nil {
			log.Fatalf("\x1b[31m[ FAIL ]\x1b[0m\n%v\n", err)
		}
		if err := systemTests(podmanCtx, os.Args[1:]); err != nil {
			log.Fatalf("\x1b[31m[ FAIL ]\x1b[0m\n%v\n", err)
		}
		fmt.Printf("\x1b[32m[ PASS ]\x1b[0m\n")
	}
}

func systemTests(podmanCtx context.Context, args []string) error {
	fmt.Println("Copying project dir to a tar")
	if err := lib.Run(`tar -C "$(pwd)" -cf /tmp/src.tar .`).Error; err != nil {
		return err
	}

	var tests []string
	data, err := os.ReadFile(installTestFile)
	if err != nil {
		return err
	}
	for line := range strings.SplitSeq(string(data), "\n") {
		if after, found := strings.CutPrefix(line, "func Test"); found && !strings.HasPrefix(after, "Main") {
			tests = append(tests, strings.SplitN(after, "(", 2)[0])
		}
	}

	var shellFns, flags []string
	if len(args) > 0 && args[0] == "-m" {
		shellFns = append(shellFns, "zsh")
		flags = append(flags, "enableStdin")
	} else {
		fmt.Println("running system tests...")
		for _, test := range tests {
			shellFns = append(shellFns, "go test -timeout 1h -run " + test + " " + strings.Join(args, " "))
		}
	}

	for _, fn := range shellFns {
		if err := createTestEV(podmanCtx); err != nil {
			return err
		}
		if err := runContainer(fn, flags...); err != nil {
			return errTestFailed
		}
	}

	return attachDiskAndBootVM(archTestDisk)
}

func unitTest(podmanCtx context.Context, args []string) error {
	if err := createTestEV(podmanCtx); err != nil {
		return err
	}

	fmt.Println("Copying project dir to a tar")
	if err := lib.Run(`tar -C "$(pwd)" -cf /tmp/src.tar .`).Error; err != nil {
		return err
	}

	var fn string
	if len(args) > 0 && args[0] == "-m" {
		fn = "zsh"
	} else {
		fmt.Println("running unit tests...")
		fn = "go test ./lib -timeout 1h " + strings.Join(args, " ")
	}
	if err := runContainer(fn); err != nil {
		return errTestFailed
	}

	return nil
}

func createTestEV(podmanCtx context.Context) error {
	// Kill any stale VM + network
	conn, err := libvirt.NewConnect("qemu:///system")
	if err != nil {
		return fmt.Errorf("libvirt connect: %w", err)
	}
	defer func(){_, _ = conn.Close()}()

	destroyDomainIfExists(conn, vmName)
	destroyNetworkIfExists(conn, "default")

	// Recreate the disk as a sparse 50GiB file (fall back to pre-existing cleanup)
	if err := recreateSparseFile(archTestDisk, "50G"); err != nil {
		return fmt.Errorf("prepare disk: %w", err)
	}

	// Ensure container image exists (build if missing)
	_, err = podmanConn(podmanCtx)
	if err != nil {
		return err
	}
	exists, err := podImages.Exists(podmanCtx, imageTag, nil)
	if err != nil {
		return fmt.Errorf("check image exists: %w", err)
	}
	if !exists {
		fmt.Println("Building image (Podman)…")
		// Ideally replace with the build function if we ever figure out how...
		out := lib.Run("podman build --dns 8.8.8.8 -f "+containerfile+" -t "+imageTag+" .")
		if !out.Success {
			return fmt.Errorf("podman build: %w", out.Error)
		}
	}

	// Define (or re-define) VM and default network from local XML files
	if err := defineOrRedefineDomain(conn, vmXMLPath); err != nil {
		return err
	}
	if err := defineOrRedefineNetwork(conn, "default", defaultNetXMLPath); err != nil {
		return err
	}
	// Start + autostart network (matches net-start + net-autostart)
	net, err := conn.LookupNetworkByName("default")
	if err != nil {
		return fmt.Errorf("lookup network: %w", err)
	}
	defer func(){_ = net.Free()}()
	_ = net.Create()
	_ = net.SetAutostart(true)

	return nil
}

