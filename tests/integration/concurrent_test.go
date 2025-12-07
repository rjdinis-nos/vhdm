package integration

import (
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"
	"time"
)

// TestConcurrentMountWithUUID tests that multiple VHDs can be mounted concurrently
// using --uuid without race conditions (simulates systemd service parallel startup)
func TestConcurrentMountWithUUID(t *testing.T) {
	skipIfNotIntegration(t)

	numVHDs := 4
	testID := fmt.Sprintf("concurrent-%d", time.Now().Unix())

	// Create test environments for multiple VHDs
	envs := make([]*TestEnvironment, numVHDs)
	for i := 0; i < numVHDs; i++ {
		env := NewTestEnvironmentWithID(t, fmt.Sprintf("%s-%d", testID, i))
		envs[i] = env
	}

	// Step 1: Create and mount all VHDs sequentially to register UUIDs
	uuids := make([]string, numVHDs)
	t.Run("Setup: Create and register VHDs", func(t *testing.T) {
		for i, env := range envs {
			// Create with format
			_, err := env.RunVHDM("create",
				"--vhd-path", env.vhdPath,
				"--size", "100M",
				"--format", "ext4",
				"-y")
			env.AssertSuccess(err, fmt.Sprintf("create VHD %d", i))

			// Mount to register UUID
			_, err = env.RunVHDM("mount",
				"--vhd-path", env.vhdPath,
				"--mount-point", env.mountPoint)
			env.AssertSuccess(err, fmt.Sprintf("mount VHD %d", i))

			// Get UUID
			output, err := env.RunVHDMQuiet("status", "--vhd-path", env.vhdPath)
			env.AssertSuccess(err, fmt.Sprintf("status VHD %d", i))

			// Extract UUID
			lines := strings.Split(output, "\n")
			for _, line := range lines {
				if strings.Contains(line, "(") && strings.Contains(line, ")") {
					start := strings.Index(line, "(")
					end := strings.Index(line, ")")
					if start != -1 && end != -1 && end > start {
						uuids[i] = strings.TrimSpace(line[start+1 : end])
						break
					}
				}
			}

			if uuids[i] == "" {
				t.Fatalf("Could not extract UUID for VHD %d from status output: %s", i, output)
			}

			t.Logf("VHD %d registered with UUID: %s", i, uuids[i])

			// Unmount for clean test
			_, err = env.RunVHDM("umount", "--mount-point", env.mountPoint)
			env.AssertSuccess(err, fmt.Sprintf("unmount VHD %d", i))
		}
	})

	// Step 2: Detach all VHDs
	t.Run("Setup: Detach all VHDs", func(t *testing.T) {
		for i, env := range envs {
			_, err := env.RunVHDM("detach", "--vhd-path", env.vhdPath)
			env.AssertSuccess(err, fmt.Sprintf("detach VHD %d", i))
		}
		t.Logf("All %d VHDs detached", numVHDs)
	})

	// Step 3: Mount all VHDs concurrently using --uuid (simulates systemd services)
	t.Run("Concurrent mount with UUID", func(t *testing.T) {
		var wg sync.WaitGroup
		errors := make([]error, numVHDs)
		outputs := make([]string, numVHDs)

		// Start all mounts simultaneously
		for i, env := range envs {
			wg.Add(1)
			go func(idx int, e *TestEnvironment, uuid string) {
				defer wg.Done()

				// Mount using UUID (like systemd service does)
				cmd := exec.Command(e.vhdmBinary, "mount",
					"--uuid", uuid,
					"--mount-point", e.mountPoint)
				output, err := cmd.CombinedOutput()
				errors[idx] = err
				outputs[idx] = string(output)
			}(i, env, uuids[i])
		}

		// Wait for all to complete
		wg.Wait()

		// Verify all succeeded
		for i, err := range errors {
			if err != nil {
				t.Errorf("VHD %d mount failed: %v\nOutput: %s", i, err, outputs[i])
			} else {
				t.Logf("VHD %d mounted successfully", i)
			}
		}
	})

	// Step 4: Verify all VHDs mounted with correct UUIDs (no UUID overwrites)
	t.Run("Verify correct UUIDs after concurrent mount", func(t *testing.T) {
		for i, env := range envs {
			output, err := env.RunVHDMQuiet("status", "--vhd-path", env.vhdPath)
			env.AssertSuccess(err, fmt.Sprintf("status VHD %d", i))

			// Verify UUID matches expected
			if !strings.Contains(output, uuids[i]) {
				t.Errorf("VHD %d has wrong UUID in status.\nExpected: %s\nGot: %s",
					i, uuids[i], output)
			} else {
				t.Logf("VHD %d has correct UUID: %s", i, uuids[i])
			}

			// Verify mounted at correct location
			if !strings.Contains(output, "mounted") {
				t.Errorf("VHD %d not showing as mounted: %s", i, output)
			}
		}
	})

	// Step 5: Verify tracking file has correct UUIDs (no overwrites)
	t.Run("Verify tracking file integrity", func(t *testing.T) {
		// Read tracking file
		trackingPath := filepath.Join(envs[0].homeDir, ".config", "vhdm", "vhd_tracking.json")
		cmd := exec.Command("cat", trackingPath)
		output, err := cmd.CombinedOutput()
		if err != nil {
			t.Fatalf("Failed to read tracking file: %v", err)
		}

		trackingContent := string(output)

		// Verify each UUID appears in tracking file
		for i, uuid := range uuids {
			if !strings.Contains(trackingContent, uuid) {
				t.Errorf("UUID for VHD %d not found in tracking file: %s", i, uuid)
			} else {
				t.Logf("Tracking file contains correct UUID for VHD %d", i)
			}
		}

		// Count UUID occurrences (each should appear exactly once)
		for i, uuid := range uuids {
			count := strings.Count(trackingContent, uuid)
			if count != 1 {
				t.Errorf("UUID for VHD %d appears %d times in tracking (expected 1): %s",
					i, count, uuid)
			}
		}
	})
}

// TestConcurrentServiceStartup tests that systemd services can start concurrently
// This is a more realistic test that simulates actual boot behavior
func TestConcurrentServiceStartup(t *testing.T) {
	skipIfNotIntegration(t)

	// This test requires sudo and systemd
	if !isRoot() {
		t.Skip("Skipping service test - requires sudo")
	}

	numServices := 3
	testID := fmt.Sprintf("svcstart-%d", time.Now().Unix())

	// Create test environments
	envs := make([]*TestEnvironment, numServices)
	serviceNames := make([]string, numServices)

	for i := 0; i < numServices; i++ {
		env := NewTestEnvironmentWithID(t, fmt.Sprintf("%s-%d", testID, i))
		envs[i] = env
		serviceNames[i] = fmt.Sprintf("test-concurrent-%s-%d", testID, i)
	}

	// Cleanup services
	defer func() {
		for _, serviceName := range serviceNames {
			exec.Command("sudo", "systemctl", "stop", serviceName+".service").Run()
			exec.Command("sudo", "systemctl", "disable", serviceName+".service").Run()
			exec.Command("sudo", "rm", filepath.Join("/usr/lib/systemd/system", serviceName+".service")).Run()
		}
		exec.Command("sudo", "systemctl", "daemon-reload").Run()
	}()

	t.Run("Setup: Create VHDs and services", func(t *testing.T) {
		for i, env := range envs {
			// Create and mount VHD
			_, err := env.RunVHDM("create", "--vhd-path", env.vhdPath, "--size", "100M", "--format", "ext4", "-y")
			env.AssertSuccess(err, fmt.Sprintf("create VHD %d", i))

			_, err = env.RunVHDM("mount", "--vhd-path", env.vhdPath, "--mount-point", env.mountPoint)
			env.AssertSuccess(err, fmt.Sprintf("mount VHD %d", i))

			// Unmount for service test
			_, err = env.RunVHDM("umount", "--mount-point", env.mountPoint)
			env.AssertSuccess(err, fmt.Sprintf("unmount VHD %d", i))

			// Create service
			cmd := exec.Command("sudo", env.vhdmBinary, "service", "create",
				"--vhd-path", env.vhdPath,
				"--mount-point", env.mountPoint,
				"--name", serviceNames[i])
			_, err = cmd.CombinedOutput()
			env.AssertSuccess(err, fmt.Sprintf("create service %d", i))
		}
	})

	t.Run("Start all services concurrently", func(t *testing.T) {
		// Build systemctl start command with all services
		args := []string{"start"}
		for _, name := range serviceNames {
			args = append(args, name+".service")
		}

		cmd := exec.Command("sudo", "systemctl", args...)
		output, err := cmd.CombinedOutput()

		if err != nil {
			t.Fatalf("Failed to start services concurrently: %v\nOutput: %s", err, string(output))
		}

		t.Logf("All %d services started concurrently", numServices)
	})

	t.Run("Verify all services active", func(t *testing.T) {
		for i, serviceName := range serviceNames {
			cmd := exec.Command("sudo", "systemctl", "is-active", serviceName+".service")
			output, _ := cmd.CombinedOutput()

			status := strings.TrimSpace(string(output))
			if status != "active" {
				t.Errorf("Service %d (%s) not active: %s", i, serviceName, status)
			} else {
				t.Logf("Service %d active", i)
			}
		}
	})
}

func isRoot() bool {
	cmd := exec.Command("id", "-u")
	output, err := cmd.Output()
	if err != nil {
		return false
	}
	return strings.TrimSpace(string(output)) == "0"
}
