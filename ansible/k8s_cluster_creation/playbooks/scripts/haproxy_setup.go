package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

func main() {
	if len(os.Args) != 3 {
		fmt.Println("Usage:", os.Args[0], "<HAProxy_IP> <Master_Node_IPs>")
		fmt.Println("Example:", os.Args[0], "10.0.1.84 '10.0.1.24,10.0.1.100'")
		os.Exit(1)
	}

	haproxyIP := os.Args[1]
	masters := strings.Split(os.Args[2], ",")

	configureHAProxy(haproxyIP, masters)
	installPackages()
}


// FUNCTIONS

func configureHAProxy(haproxyIP string, masters []string) {
	configFile := "/etc/haproxy/haproxy.cfg"

	// Check if the file already exists
	if _, err := os.Stat(configFile); err == nil {
		fmt.Println("[WARNING] Config file already exists. Continuing to use the existing file.")
		// Open the existing file with read and write permissions
		file, err := os.OpenFile(configFile, os.O_RDWR, 0644)
		if err != nil {
			fmt.Println("[ERROR] Error opening existing config file:", err)
			os.Exit(1)
		}
		defer file.Close()
		// You can now proceed to use 'file' to write configurations
	} else if os.IsNotExist(err) {
		// File does not exist, create a new file
		file, err := os.Create(configFile)
		if err != nil {
			fmt.Println("[ERROR] Error creating config file:", err)
			os.Exit(1)
		}
		defer file.Close()
		// You can now proceed to use 'file' to write configurations
	} else {
		// Some other error occurred while checking the file
		fmt.Println("[ERROR] Error checking config file:", err)
		os.Exit(1)
	}

	writer := bufio.NewWriter(file)

	_, _ = writer.WriteString(fmt.Sprintf("frontend kubernetes-frontend\n    bind %s:6443\n    mode tcp\n    option tcplog\n    default_backend kubernetes-backend\n\n", haproxyIP))
	for i, master := range masters {
		_, _ = writer.WriteString(fmt.Sprintf("    server kmaster%d %s:6443 check fall 3 rise 2\n", i+1, master))
	}
	_ = writer.Flush()

	fmt.Println("[INFORMATION] HAProxy configuration has been updated.")
	executeCommand("sudo", []string{"systemctl", "restart", "haproxy"})
	fmt.Println("[INFORMATION] HAProxy has been restarted.")
}

func installPackages() {
	executeCommand("sudo", []string{"apt-get", "update", "-y"})
	installPackage("haproxy")
	installPackage("keepalived")
}

func installPackage(packageName string) {
	if !isCommandAvailable(packageName) {
		fmt.Printf("[INFORMATION] Installing %s...\n", packageName)
		executeCommand("sudo", []string{"apt-get", "install", "-y", packageName})
		fmt.Printf("[INFORMATION] %s installed.\n", packageName)
	}
}

func isCommandAvailable(name string) bool {
	cmd := exec.Command("command", "-v", name)
	err := cmd.Run()
	return err == nil
}

func executeCommand(command string, args []string) {
	cmd := exec.Command(command, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		fmt.Printf("[ERROR] Error executing %s: %s\n", command, err)
	}
}
