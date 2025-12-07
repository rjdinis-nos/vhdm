package integration

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// TestServiceCreationRequiresTrackedVHD tests that service creation enforces UUID tracking
func TestServiceCreationRequiresTrackedVHD(t *testing.T) {
	skipIfNotIntegration(t)

	env := NewTestEnvironment(t)
	testID := fmt.Sprintf("svc-%d", time.Now().Unix())
	serviceName := fmt.Sprintf("test-service-%s", testID)
	serviceFile := filepath.Join("/usr/lib/systemd/system", serviceName+".service")

	// Cleanup service file if it exists
	defer func() {
		if _, err := os.Stat(serviceFile); err == nil {
			exec.Command("sudo", "rm", serviceFile).Run()
			exec.Command("sudo", "systemctl", "daemon-reload").Run()
		}
	}()

	t.Run("Service creation fails for untracked VHD", func(t *testing.T) {
		// Create VHD but don't mount it (so UUID won't be tracked)
		_, err := env.RunVHDM("create",
			"--vhd-path", env.vhdPath,
			"--size", testVHDSize)
		env.AssertSuccess(err, "create")

		// Try to create service without mounting first
		cmd := exec.Command("sudo", env.vhdmBinary, "service", "create",
			"--vhd-path", env.vhdPath,
			"--mount-point", env.mountPoint,
			"--name", serviceName)
		output2, err := cmd.CombinedOutput()
		outputStr := string(output2)

		// Should fail with clear error message
		if err == nil {
			t.Fatalf("Expected service creation to fail for untracked VHD, but it succeeded")
		}

		// Check error message includes helpful instructions
		env.AssertContains(outputStr, "not tracked")
		env.AssertContains(outputStr, "mount --vhd-path")
		env.AssertContains(outputStr, "status --vhd-path")

		t.Logf("Correct error message shown")
	})
}

// TestServiceCreationWithTrackedVHD tests successful service creation with tracked UUID
func TestServiceCreationWithTrackedVHD(t *testing.T) {
	skipIfNotIntegration(t)

	env := NewTestEnvironment(t)
	testID := fmt.Sprintf("svc-%d", time.Now().Unix())
	serviceName := fmt.Sprintf("test-service-%s", testID)
	serviceFile := filepath.Join("/usr/lib/systemd/system", serviceName+".service")

	// Cleanup service file if it exists
	defer func() {
		if _, err := os.Stat(serviceFile); err == nil {
			exec.Command("sudo", "systemctl", "disable", serviceName+".service").Run()
			exec.Command("sudo", "rm", serviceFile).Run()
			exec.Command("sudo", "systemctl", "daemon-reload").Run()
		}
	}()

	var uuid string

	t.Run("Setup: Create and mount VHD to register UUID", func(t *testing.T) {
		// Create and format VHD
		_, err := env.RunVHDM("create",
			"--vhd-path", env.vhdPath,
			"--size", testVHDSize,
			"--format", testFSType,
			"-y")
		env.AssertSuccess(err, "create with format")

		// Mount to register in tracking
		_, err = env.RunVHDM("mount",
			"--vhd-path", env.vhdPath,
			"--mount-point", env.mountPoint)
		env.AssertSuccess(err, "mount")

		// Get UUID from status
		output, err := env.RunVHDMQuiet("status", "--vhd-path", env.vhdPath)
		env.AssertSuccess(err, "status")

		// Extract UUID (format: path (uuid): status)
		lines := strings.Split(output, "\n")
		for _, line := range lines {
			if strings.Contains(line, "(") && strings.Contains(line, ")") {
				start := strings.Index(line, "(")
				end := strings.Index(line, ")")
				if start != -1 && end != -1 && end > start {
					uuid = strings.TrimSpace(line[start+1 : end])
					break
				}
			}
		}

		if uuid == "" {
			t.Fatalf("Could not extract UUID from status output: %s", output)
		}

		t.Logf("VHD tracked with UUID: %s", uuid)

		// Unmount before creating service
		_, err = env.RunVHDM("umount", "--mount-point", env.mountPoint)
		env.AssertSuccess(err, "umount")
	})

	t.Run("Service creation succeeds for tracked VHD", func(t *testing.T) {
		cmd := exec.Command("sudo", env.vhdmBinary, "service", "create",
			"--vhd-path", env.vhdPath,
			"--mount-point", env.mountPoint,
			"--name", serviceName)
		output, err := cmd.CombinedOutput()
		outputStr := string(output)

		env.AssertSuccess(err, "service create")
		env.AssertContains(outputStr, "Service created")
		env.AssertContains(outputStr, serviceName)
		env.AssertContains(outputStr, uuid)

		t.Logf("Service created successfully with UUID: %s", uuid)
	})

	t.Run("Service file uses UUID in ExecStart", func(t *testing.T) {
		// Check service file exists
		if _, err := os.Stat(serviceFile); os.IsNotExist(err) {
			t.Fatalf("Service file not created: %s", serviceFile)
		}

		// Read service file
		content, err := os.ReadFile(serviceFile)
		if err != nil {
			t.Fatalf("Failed to read service file: %v", err)
		}

		serviceContent := string(content)

		// Verify uses --uuid instead of --vhd-path
		if !strings.Contains(serviceContent, "--uuid") {
			t.Errorf("Service file should use --uuid in ExecStart")
		}
		if !strings.Contains(serviceContent, uuid) {
			t.Errorf("Service file should contain tracked UUID: %s", uuid)
		}
		if strings.Contains(serviceContent, "--vhd-path") && strings.Contains(serviceContent, "ExecStart") {
			t.Errorf("Service file should NOT use --vhd-path in ExecStart (race condition prone)")
		}

		// Verify has required systemd configuration
		env.AssertContains(serviceContent, "After=local-fs.target mnt-c.mount")
		env.AssertContains(serviceContent, "Requires=mnt-c.mount")
		env.AssertContains(serviceContent, "PATH=")
		env.AssertContains(serviceContent, "/mnt/c/WINDOWS")

		t.Logf("Service file correctly configured with UUID-based mounting")
	})

	t.Run("Service enable succeeds", func(t *testing.T) {
		cmd := exec.Command("sudo", env.vhdmBinary, "service", "enable",
			"--name", serviceName)
		output, err := cmd.CombinedOutput()
		outputStr := string(output)

		env.AssertSuccess(err, "service enable")
		env.AssertContains(outputStr, "enabled")
	})

	t.Run("Service list shows created service", func(t *testing.T) {
		cmd := exec.Command("sudo", env.vhdmBinary, "service", "list")
		output, err := cmd.CombinedOutput()
		outputStr := string(output)

		env.AssertSuccess(err, "service list")
		env.AssertContains(outputStr, serviceName)
	})

	t.Run("Service disable and remove", func(t *testing.T) {
		// Disable
		cmd := exec.Command("sudo", env.vhdmBinary, "service", "disable",
			"--name", serviceName)
		_, err := cmd.CombinedOutput()
		env.AssertSuccess(err, "service disable")

		// Remove
		cmd = exec.Command("sudo", env.vhdmBinary, "service", "remove",
			"--name", serviceName)
		_, err = cmd.CombinedOutput()
		env.AssertSuccess(err, "service remove")

		// Verify file deleted
		if _, err := os.Stat(serviceFile); err == nil {
			t.Errorf("Service file should be deleted after remove")
		}
	})
}
