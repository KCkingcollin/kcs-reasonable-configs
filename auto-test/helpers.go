package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	sh "unix-shell"

	"github.com/containers/podman/v5/pkg/bindings"
	"libvirt.org/go/libvirt"
)

const (
	archTestDisk = "/var/lib/libvirt/images/arch-test.raw"
	// vmIP         = "10.0.69.3"
	// sshPort      = 22
	vmName       = "arch-test-vm"

	imageTag            = "kcs-reasonable-configs-install-ev"
	containerfile       = "Dockerfile.main-ev" // your build file
	vmXMLPath           = "./arch-test-vm.xml" // same as $vmName.xml
	defaultNetXMLPath   = "./default.xml"
	podmanRootfulSocket = "unix:///run/podman/podman.sock"
)

// // Start VM and wait for SSH (your startAndConnect)
// func startAndConnectVM(name, ip string, port int) error {
// 	conn, err := libvirt.NewConnect("qemu:///system")
// 	if err != nil {
// 		return fmt.Errorf("libvirt connect: %w", err)
// 	}
// 	defer func(){_, _ = conn.Close()}()
//
// 	dom, err := conn.LookupDomainByName(name)
// 	if err != nil {
// 		return fmt.Errorf("lookup domain: %w", err)
// 	}
// 	defer func(){_ = dom.Free()}()
//
// 	if err := dom.Create(); err != nil {
// 		return fmt.Errorf("domain start: %w", err)
// 	}
// 	fmt.Println("VM booting...")
//
// 	// Exponential-ish backoff
// 	waitTime := 500 * time.Millisecond
// 	attempts := 1
// 	waited := time.Duration(0)
//
// 	fmt.Printf("\n\n\n")
// 	for {
// 		if attempts > 30 {
// 			return errors.New("failed to connect to VM (SSH unopened)")
// 		}
// 		if connSSH(ip, port, time.Second) == nil {
// 			break
// 		}
// 		// pretty status lines like your script
// 		fmt.Printf("\x1b[1A\x1b[2K\x1b[1A\x1b[2K\x1b[1A\x1b[2K")
// 		fmt.Printf("Connection attempts: %d\nWaiting for %0.1fs\nWaited %0.1fs\n",
// 			attempts, waitTime.Seconds(), waited.Seconds())
//
// 		attempts++
// 		time.Sleep(waitTime)
// 		waited += waitTime
// 		// ~1.25x backoff
// 		waitTime = time.Duration(float64(waitTime) * 1.25)
// 	}
//
// 	// Refresh known_hosts entry like your sed + ssh-keyscan
// 	if err := refreshKnownHosts(ip); err != nil {
// 		// non-fatal; keep parity with the “best-effort” nature of ssh-keyscan path
// 		fmt.Fprintf(os.Stderr, "known_hosts update warning: %v\n", err)
// 	}
// 	fmt.Println("Connection established")
// 	return nil
// }

// Attach raw disk as vda and boot
func attachDiskAndBootVM(diskPath string) error {
	conn, err := libvirt.NewConnect("qemu:///system")
	if err != nil {
		return fmt.Errorf("libvirt connect: %w", err)
	}
	defer func(){_, _ = conn.Close()}()

	dom, err := conn.LookupDomainByName(vmName)
	if err != nil {
		return fmt.Errorf("lookup domain: %w", err)
	}
	defer func(){_ = dom.Free()}()

	sh.RunS("virsh attach-disk", vmName, diskPath, "vda --persistent --subdriver raw")

	return dom.Create()
}

func podmanConn(newCtx context.Context) (context.Context, error) {
	dest := os.Getenv("CONTAINER_HOST")
	if dest == "" {
		dest = podmanRootfulSocket
	}
	return bindings.NewConnection(newCtx, dest)
}

func destroyDomainIfExists(conn *libvirt.Connect, name string) {
	dom, err := conn.LookupDomainByName(name)
	if err == nil {
		defer func(){_ = dom.Free()}()
		_ = dom.Destroy()
		_ = dom.UndefineFlags(libvirt.DOMAIN_UNDEFINE_NVRAM)
		_ = dom.Undefine()
	}
}

func destroyNetworkIfExists(conn *libvirt.Connect, name string) {
	net, err := conn.LookupNetworkByName(name)
	if err == nil {
		defer func(){_ = net.Free()}()
		_ = net.Destroy()
		_ = net.Undefine()
	}
}

func defineOrRedefineDomain(conn *libvirt.Connect, path string) error {
	xml, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read domain xml: %w", err)
	}
	// Either define or redefine, then start later.
	if _, err := conn.DomainDefineXML(string(xml)); err != nil {
		return fmt.Errorf("define domain: %w", err)
	}
	return nil
}

func defineOrRedefineNetwork(conn *libvirt.Connect, name, path string) error {
	xml, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("read network xml: %w", err)
	}
	net, _ := conn.LookupNetworkByName(name)
	if net != nil {
		_ = net.Destroy()
		_ = net.Undefine()
		_ = net.Free()
	}
	if _, err := conn.NetworkDefineXML(string(xml)); err != nil {
		return fmt.Errorf("define network: %w", err)
	}
	return nil
}

// automatically sets up and starts the container environment and runs the shellFn in a interactive environment
// 
// optionally add extra flags for the Run function
func runContainer(shellFn string) error {
	const testCon = "testContainer"
	out := sh.RunS(
		"podman", "run", "--replace", "-dit", "--name", testCon, "--privileged",
		"-v", "/tmp/src.tar:/tmp/src.tar:ro", 
		"-v", archTestDisk+":/images/arch-test.raw",
		"-v", "/dev/:/dev/",
		imageTag,
	)
	if out.Error != nil {
		return out.Error
	}
	defer sh.RunS("podman kill", testCon)

	out = sh.RunS(
		"podman", "exec", testCon,
		"tar", "-C", ".", "-xf", "/tmp/src.tar",
	)
	if out.Error != nil {
		return out.Error
	}

	out = sh.RunF(
		sh.RunFlags{NoShell: true, EnableStdin: true},
		append(
			[]string{"podman", "exec", "-it", testCon},
			strings.Fields(shellFn)...
		)...
	)
	return out.Error
}

// size is a int plus a type suffix like this: 50G
func recreateSparseFile(path string, size string) error {
	sh.Mkdir(filepath.Dir(path))
	if err := sh.Run("fallocate -l ", size, path).Error; err != nil {return err}
	for !sh.RunS("wipefs", "-a", path).Success {}
	for _, err := os.Stat(path); err != nil; _, err = os.Stat(path) {
		if errors.Is(err, os.ErrNotExist) {return err}
	}
	return nil
}

// func connSSH(ip string, port int, timeout time.Duration) error {
// 	d := net.Dialer{Timeout: timeout}
// 	c, err := d.Dial("tcp", fmt.Sprintf("%s:%d", ip, port))
// 	if err != nil {
// 		return err
// 	}
// 	_ = c.Close()
// 	return nil
// }

// func refreshKnownHosts(ip string) error {
// 	kh := filepath.Join(os.Getenv("HOME"), ".ssh", "known_hosts")
// 	_ = os.MkdirAll(filepath.Dir(kh), 0o700)
// 	// drop existing lines for the IP
// 	b, _ := os.ReadFile(kh)
// 	var out bytes.Buffer
// 	for line := range bytes.SplitSeq(b, []byte{'\n'}) {
// 		if !bytes.Contains(line, []byte(ip)) {
// 			out.Write(line)
// 			out.WriteByte('\n')
// 		}
// 	}
// 	// get ssh-keyscan output
// 	res := lib.Run("ssh-keyscan", "-t", "ed25519", ip)
// 	if res.Error != nil {
// 		// keep partial write; just warn
// 		_ = os.WriteFile(kh, out.Bytes(), 0o600)
// 		return res.Error
// 	}
// 	out.WriteString(res.Output)
// 	return os.WriteFile(kh, out.Bytes(), 0o600)
// }
