package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"os"
	fp "path/filepath"
	"strings"
	sh "unix-shell"

	podImages "github.com/containers/podman/v5/pkg/bindings/images"
	libvirt "libvirt.org/go/libvirt"
)

type TestSuite struct {
	UnitTests 	[]string
	SysTests 	[]string
}

var errTestFailed = errors.New("")

func main() {
	if os.Geteuid() != 0 {
		fmt.Println("needs to be run as root")
		os.Exit(1)
	}

	newCtx := context.Background()

	var testPaths TestSuite
	var args []string
	for _, arg := range os.Args[1:] {
		loc, err := os.Stat(fp.Clean(arg))
		switch {
		case err == nil:
			if !loc.IsDir() {
				arg = fp.Dir(arg)
			}

			if len(args) > 0 && args[len(args)-1] == "system" {
				testPaths.SysTests = append(testPaths.SysTests, fp.Clean(arg))
			} else {
				testPaths.UnitTests = append(testPaths.UnitTests, fp.Clean(arg))
			}
		case !strings.HasPrefix(arg, ".") && !strings.Contains(arg, "/"):
			args = append(args, arg)
		default:
			fmt.Fprintf(os.Stderr, "Invalid path: %s", arg)
			os.Exit(2)
		}
	}

	for i := 0; len(args) > i; i++ {
		arg := args[i]
		if arg == "unit" || arg == "system" {
			args = append(args[:i], args[i+1:]...)
			i--
		}
	}

	if len(testPaths.SysTests) < 1 && len(testPaths.UnitTests) < 1 {
		fmt.Fprintf(os.Stderr, "usage: %s {unit|system} go/test/location(s) [args]\n", os.Args[0])
		os.Exit(2)
	}

	podmanCtx, err := podmanConn(newCtx)
	if err != nil {
		log.Fatalln("Big failure in getting the podman connection")
	}

	if err := runTests(podmanCtx, testPaths, args); err != nil {
		log.Fatalf("\n\x1b[31m[ FAIL ]\x1b[0m\n%v\n", err)
	}
	fmt.Printf("\n\x1b[32m[ PASS ]\x1b[0m\n")
}

func runTests(podmanCtx context.Context, testLocations TestSuite, args []string) error {
	fmt.Println("Copying project dir to a tar")
	if err := sh.Run(`tar -C "$(pwd)" -cf /tmp/src.tar .`).Error; err != nil {
		return err
	}

	var runArg struct{
		Exists bool
		TestName string
	}
	for i := 0; len(args) > i; i++ {
		arg := args[i]
		if arg == "-run" {
			if len(args) <= i+1 {
				return fmt.Errorf("error: -run specified but no test name given")
			}
			runArg = struct{Exists bool; TestName string}{true, args[i+1]}
			args = append(args[:i], args[i+2:]...)
			i--
		}
	}

	if len(args) > 0 && args[0] == "-m" {
		if err := createTestEV(podmanCtx); err != nil {
			return err
		}
		if err := runContainer("zsh"); err != nil {
			return errTestFailed
		}
	} else {
		if runArg.Exists {
			var location string
			if len(testLocations.SysTests) == 0 {
				location = testLocations.UnitTests[0]
			} else {
				location = testLocations.SysTests[0] 
			}
			shellFn := "go test " + location + " -timeout 30m -run " + runArg.TestName + " " + strings.Join(args, " ")
			if err := createTestEV(podmanCtx); err != nil {
				return err
			}

			if err := runContainer(shellFn); err != nil {
				return errTestFailed
			}

			if len(testLocations.SysTests) > 0 {
				err := attachDiskAndBootVM(archTestDisk)
				if err != nil {
					return err
				}
				fmt.Println("press enter to continue")
				_, _ = fmt.Scanln()
			}
		} else {
			for _, location := range testLocations.UnitTests {
				shellFn := "go test " + location + " -timeout 5m " + strings.Join(args, " ")

				if err := createTestEV(podmanCtx); err != nil {
					return err
				}

				if err := runContainer(shellFn); err != nil {
					return errTestFailed
				}
			}

			for _, location := range testLocations.SysTests {
				var testFiles []string
				files, err := os.ReadDir(location)
				if err != nil {
					return err
				}
				for _, file := range files {
					if strings.HasSuffix(file.Name(), "_test.go") {
						testFiles = append(testFiles, fp.Join(location, file.Name()))
					}
				}

				var tests []string
				for _, loc := range testFiles {
					data, err := os.ReadFile(fp.Clean(loc))
					if err != nil {
						return err
					}
					for line := range strings.SplitSeq(string(data), "\n") {
						if after, found := strings.CutPrefix(line, "func Test"); found && !strings.HasPrefix(after, "Main") {
							tests = append(tests, strings.SplitN(after, "(", 2)[0])
						}
					}
				}

				var shellFns []string
				for _, test := range tests {
					shellFns = append(shellFns, "go test " + location + " -timeout 15m -run " + test + " " + strings.Join(args, " "))
				}

				for _, fn := range shellFns {
					if err := createTestEV(podmanCtx); err != nil {
						return err
					}
					if err := runContainer(fn); err != nil {
						return errTestFailed
					}

					err = attachDiskAndBootVM(archTestDisk)
					if err != nil {
						return err
					}
					fmt.Println("press enter to continue")
					_, _ = fmt.Scanln()
				}
			}
		}
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
		out := sh.Run("podman build --dns 8.8.8.8 -f "+containerfile+" -t "+imageTag+" .")
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

