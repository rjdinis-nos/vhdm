package integration

import (
	"strings"
	"testing"
)

// TestInvalidInputs tests that invalid inputs are rejected
func TestInvalidInputs(t *testing.T) {
	skipIfNotIntegration(t)
	
	env := NewTestEnvironment(t)
	
	t.Run("Attach with invalid path format", func(t *testing.T) {
		_, err := env.RunVHDM("attach",
			"--vhd-path", "/invalid/path.vhdx") // Unix path, not Windows
		if err == nil {
			t.Error("Expected error for invalid path format")
		}
	})
	
	t.Run("Attach with path traversal", func(t *testing.T) {
		_, err := env.RunVHDM("attach",
			"--vhd-path", "C:/VMs/../secret/file.vhdx")
		if err == nil {
			t.Error("Expected error for path traversal")
		}
	})
	
	t.Run("Attach with command injection attempt", func(t *testing.T) {
		_, err := env.RunVHDM("attach",
			"--vhd-path", "C:/VMs/file.vhdx; rm -rf /")
		if err == nil {
			t.Error("Expected error for command injection attempt")
		}
	})
	
	t.Run("Mount with invalid mount point", func(t *testing.T) {
		_, err := env.RunVHDM("mount",
			"--vhd-path", env.vhdPath,
			"--mount-point", "relative/path")
		if err == nil {
			t.Error("Expected error for relative mount point")
		}
	})
	
	t.Run("Format with invalid device name", func(t *testing.T) {
		_, err := env.RunVHDM("format",
			"--dev-name", "invalid",
			"--type", "ext4",
			"-y")
		if err == nil {
			t.Error("Expected error for invalid device name")
		}
	})
	
	t.Run("Format with invalid filesystem type", func(t *testing.T) {
		_, err := env.RunVHDM("format",
			"--dev-name", "sdd",
			"--type", "invalidfs",
			"-y")
		if err == nil {
			t.Error("Expected error for invalid filesystem type")
		}
	})
	
	t.Run("Create with invalid size", func(t *testing.T) {
		_, err := env.RunVHDM("create",
			"--vhd-path", env.vhdPath,
			"--size", "invalid")
		if err == nil {
			t.Error("Expected error for invalid size")
		}
	})
}

// TestNonExistentVHD tests operations on non-existent VHDs
func TestNonExistentVHD(t *testing.T) {
	skipIfNotIntegration(t)
	
	env := NewTestEnvironment(t)
	nonExistentPath := "C:/NonExistent/Path/disk.vhdx"
	
	t.Run("Attach non-existent VHD", func(t *testing.T) {
		output, err := env.RunVHDM("attach",
			"--vhd-path", nonExistentPath)
		if err == nil {
			t.Error("Expected error for non-existent VHD")
		}
		env.AssertContains(output, "not found")
	})
	
	t.Run("Mount non-existent VHD", func(t *testing.T) {
		output, err := env.RunVHDM("mount",
			"--vhd-path", nonExistentPath,
			"--mount-point", env.mountPoint)
		if err == nil {
			t.Error("Expected error for non-existent VHD")
		}
		env.AssertContains(output, "not found")
	})
	
	t.Run("Delete non-existent VHD", func(t *testing.T) {
		output, err := env.RunVHDM("delete",
			"--vhd-path", nonExistentPath,
			"-y")
		if err == nil {
			t.Error("Expected error for non-existent VHD")
		}
		env.AssertContains(output, "not found")
	})
}

// TestUnformattedVHD tests mounting an unformatted VHD
func TestUnformattedVHD(t *testing.T) {
	skipIfNotIntegration(t)
	
	env := NewTestEnvironment(t)
	
	// Change VHD path
	env.vhdPath = strings.Replace(env.vhdPath, ".vhdx", "_unformatted.vhdx", 1)
	
	t.Run("Create unformatted VHD", func(t *testing.T) {
		_, err := env.RunVHDM("create",
			"--vhd-path", env.vhdPath,
			"--size", testVHDSize)
		// Note: no --format flag
		env.AssertSuccess(err, "create")
	})
	
	t.Run("Attach unformatted VHD", func(t *testing.T) {
		output, err := env.RunVHDM("attach",
			"--vhd-path", env.vhdPath)
		env.AssertSuccess(err, "attach")
		// Should indicate unformatted
		env.AssertContains(output, "unformatted")
	})
	
	t.Run("Mount unformatted VHD should fail", func(t *testing.T) {
		output, err := env.RunVHDM("mount",
			"--vhd-path", env.vhdPath,
			"--mount-point", env.mountPoint)
		if err == nil {
			t.Error("Expected error when mounting unformatted VHD")
		}
		env.AssertContains(output, "not formatted")
	})
	
	t.Run("Cleanup", func(t *testing.T) {
		env.RunVHDM("detach", "--vhd-path", env.vhdPath)
	})
}

// TestQuietMode tests quiet mode output
func TestQuietMode(t *testing.T) {
	skipIfNotIntegration(t)
	
	env := NewTestEnvironment(t)
	
	// Change VHD path
	env.vhdPath = strings.Replace(env.vhdPath, ".vhdx", "_quiet.vhdx", 1)
	
	t.Run("Create VHD with format", func(t *testing.T) {
		_, err := env.RunVHDM("create",
			"--vhd-path", env.vhdPath,
			"--size", testVHDSize,
			"--format", testFSType)
		env.AssertSuccess(err, "create")
	})
	
	t.Run("Quiet status output", func(t *testing.T) {
		output, err := env.RunVHDMQuiet("status")
		env.AssertSuccess(err, "status")
		
		// Quiet mode should have simple output format
		// path (uuid): status
		if !strings.Contains(output, ":") {
			t.Errorf("Quiet mode output should contain colon-separated format: %s", output)
		}
		
		// Should NOT have table formatting
		if strings.Contains(output, "+--") {
			t.Errorf("Quiet mode should not have table borders: %s", output)
		}
	})
	
	t.Run("Cleanup", func(t *testing.T) {
		env.RunVHDM("umount", "--vhd-path", env.vhdPath)
	})
}

// TestDebugMode tests debug mode output
func TestDebugMode(t *testing.T) {
	skipIfNotIntegration(t)
	
	env := NewTestEnvironment(t)
	
	t.Run("Debug status shows commands", func(t *testing.T) {
		output, err := env.RunVHDM("-d", "status")
		env.AssertSuccess(err, "status with debug")
		
		// Debug mode should show executed commands
		env.AssertContains(output, "[DEBUG]")
		env.AssertContains(output, "lsblk")
	})
}
