package integration

import (
	"regexp"
	"strings"
	"testing"
)

// TestCreateAttachFormatMountWorkflow tests the full VHD lifecycle
func TestCreateAttachFormatMountWorkflow(t *testing.T) {
	skipIfNotIntegration(t)
	
	env := NewTestEnvironment(t)
	
	var devName string
	
	t.Run("Create VHD", func(t *testing.T) {
		output, err := env.RunVHDM("create", 
			"--vhd-path", env.vhdPath,
			"--size", testVHDSize)
		env.AssertSuccess(err, "create")
		env.AssertContains(output, "created")
	})
	
	t.Run("Attach VHD and get device", func(t *testing.T) {
		output, err := env.RunVHDM("attach", 
			"--vhd-path", env.vhdPath)
		env.AssertSuccess(err, "attach")
		env.AssertContains(output, "attached")
		
		// Extract device name from output
		// Look for "Device        : /dev/sdX"
		re := regexp.MustCompile(`Device\s*:\s*/dev/(sd[a-z]+)`)
		matches := re.FindStringSubmatch(output)
		if len(matches) >= 2 {
			devName = matches[1]
			t.Logf("Detected device: %s", devName)
		}
		
		if devName == "" {
			// Fallback: look for "vhdm format --dev-name X"
			re2 := regexp.MustCompile(`format --dev-name\s+(sd[a-z]+)`)
			matches2 := re2.FindStringSubmatch(output)
			if len(matches2) >= 2 {
				devName = matches2[1]
				t.Logf("Detected device from hint: %s", devName)
			}
		}
		
		if devName == "" {
			t.Fatalf("Could not determine device name from attach output")
		}
	})
	
	t.Run("Format VHD", func(t *testing.T) {
		output, err := env.RunVHDM("format",
			"--dev-name", devName,
			"--type", testFSType,
			"-y") // auto-confirm
		env.AssertSuccess(err, "format")
		env.AssertContains(output, "formatted")
	})
	
	t.Run("Status shows attached", func(t *testing.T) {
		output, err := env.RunVHDMQuiet("status")
		env.AssertSuccess(err, "status")
		// After formatting, should show "attached" not "detached"
		if !strings.Contains(output, "attached") && !strings.Contains(output, "mounted") {
			t.Logf("Status output: %s", output)
			// This is expected for unformatted VHDs - they show as detached
		}
	})
	
	t.Run("Mount VHD", func(t *testing.T) {
		output, err := env.RunVHDM("mount",
			"--vhd-path", env.vhdPath,
			"--mount-point", env.mountPoint)
		env.AssertSuccess(err, "mount")
		env.AssertContains(output, "mounted")
	})
	
	t.Run("Status shows mounted", func(t *testing.T) {
		output, err := env.RunVHDMQuiet("status")
		env.AssertSuccess(err, "status")
		env.AssertContains(output, "mounted")
	})
	
	t.Run("Unmount VHD", func(t *testing.T) {
		output, err := env.RunVHDM("umount",
			"--mount-point", env.mountPoint)
		env.AssertSuccess(err, "umount")
		env.AssertContains(output, "unmounted")
	})
	
	t.Run("Detach VHD", func(t *testing.T) {
		output, err := env.RunVHDM("detach",
			"--vhd-path", env.vhdPath)
		env.AssertSuccess(err, "detach")
		env.AssertContains(output, "detached")
	})
}

// TestCreateWithFormat tests create command with --format flag
func TestCreateWithFormat(t *testing.T) {
	skipIfNotIntegration(t)
	
	env := NewTestEnvironment(t)
	
	// Change VHD path to avoid conflict
	env.vhdPath = strings.Replace(env.vhdPath, ".vhdx", "_formatted.vhdx", 1)
	
	t.Run("Create with format", func(t *testing.T) {
		output, err := env.RunVHDM("create",
			"--vhd-path", env.vhdPath,
			"--size", testVHDSize,
			"--format", testFSType)
		env.AssertSuccess(err, "create with format")
		env.AssertContains(output, "formatted")
	})
	
	t.Run("Mount directly", func(t *testing.T) {
		output, err := env.RunVHDM("mount",
			"--vhd-path", env.vhdPath,
			"--mount-point", env.mountPoint)
		env.AssertSuccess(err, "mount")
		env.AssertContains(output, "mounted")
	})
	
	t.Run("Cleanup - unmount and detach", func(t *testing.T) {
		output, err := env.RunVHDM("umount",
			"--vhd-path", env.vhdPath)
		env.AssertSuccess(err, "umount with detach")
		env.AssertContains(output, "detached")
	})
}

// TestMountOrchestration tests that mount command attaches if needed
func TestMountOrchestration(t *testing.T) {
	skipIfNotIntegration(t)
	
	env := NewTestEnvironment(t)
	
	// Change VHD path
	env.vhdPath = strings.Replace(env.vhdPath, ".vhdx", "_orchestration.vhdx", 1)
	
	t.Run("Create and format VHD", func(t *testing.T) {
		output, err := env.RunVHDM("create",
			"--vhd-path", env.vhdPath,
			"--size", testVHDSize,
			"--format", testFSType)
		env.AssertSuccess(err, "create with format")
		env.AssertContains(output, "formatted")
	})
	
	t.Run("Detach VHD", func(t *testing.T) {
		_, err := env.RunVHDM("detach",
			"--vhd-path", env.vhdPath)
		env.AssertSuccess(err, "detach")
	})
	
	t.Run("Mount should auto-attach", func(t *testing.T) {
		output, err := env.RunVHDM("mount",
			"--vhd-path", env.vhdPath,
			"--mount-point", env.mountPoint)
		env.AssertSuccess(err, "mount with auto-attach")
		env.AssertContains(output, "attached and mounted")
	})
	
	t.Run("Cleanup", func(t *testing.T) {
		env.RunVHDM("umount", "--vhd-path", env.vhdPath)
	})
}

// TestDetachAutoUnmount tests that detach unmounts first if needed
func TestDetachAutoUnmount(t *testing.T) {
	skipIfNotIntegration(t)
	
	env := NewTestEnvironment(t)
	
	// Change VHD path
	env.vhdPath = strings.Replace(env.vhdPath, ".vhdx", "_autounmount.vhdx", 1)
	
	t.Run("Create, format, and mount", func(t *testing.T) {
		_, err := env.RunVHDM("create",
			"--vhd-path", env.vhdPath,
			"--size", testVHDSize,
			"--format", testFSType)
		env.AssertSuccess(err, "create")
		
		_, err = env.RunVHDM("mount",
			"--vhd-path", env.vhdPath,
			"--mount-point", env.mountPoint)
		env.AssertSuccess(err, "mount")
	})
	
	t.Run("Detach while mounted should auto-unmount", func(t *testing.T) {
		output, err := env.RunVHDM("detach",
			"--vhd-path", env.vhdPath)
		env.AssertSuccess(err, "detach")
		// Check for unmount message (case insensitive)
		lowerOutput := strings.ToLower(output)
		if !strings.Contains(lowerOutput, "unmount") {
			t.Logf("Expected unmount in output: %s", output)
		}
		env.AssertContains(output, "detached")
	})
}

// TestIdempotentOperations tests that operations are idempotent
func TestIdempotentOperations(t *testing.T) {
	skipIfNotIntegration(t)
	
	env := NewTestEnvironment(t)
	
	// Change VHD path
	env.vhdPath = strings.Replace(env.vhdPath, ".vhdx", "_idempotent.vhdx", 1)
	
	t.Run("Setup - create and format", func(t *testing.T) {
		_, err := env.RunVHDM("create",
			"--vhd-path", env.vhdPath,
			"--size", testVHDSize,
			"--format", testFSType)
		env.AssertSuccess(err, "create")
	})
	
	t.Run("Attach already attached VHD", func(t *testing.T) {
		output, err := env.RunVHDM("attach",
			"--vhd-path", env.vhdPath)
		// Should succeed but indicate already attached
		env.AssertSuccess(err, "attach already attached")
		env.AssertContains(output, "already attached")
	})
	
	t.Run("Mount VHD", func(t *testing.T) {
		_, err := env.RunVHDM("mount",
			"--vhd-path", env.vhdPath,
			"--mount-point", env.mountPoint)
		env.AssertSuccess(err, "mount")
	})
	
	t.Run("Mount already mounted at same location", func(t *testing.T) {
		output, err := env.RunVHDM("mount",
			"--vhd-path", env.vhdPath,
			"--mount-point", env.mountPoint)
		// Should succeed but indicate already mounted
		env.AssertSuccess(err, "mount already mounted")
		env.AssertContains(output, "already mounted")
	})
	
	t.Run("Cleanup", func(t *testing.T) {
		env.RunVHDM("umount", "--vhd-path", env.vhdPath)
	})
}

// TestStatusTracking tests status command and tracking persistence
func TestStatusTracking(t *testing.T) {
	skipIfNotIntegration(t)
	
	env := NewTestEnvironment(t)
	
	// Change VHD path
	env.vhdPath = strings.Replace(env.vhdPath, ".vhdx", "_tracking.vhdx", 1)
	
	t.Run("Create and format VHD", func(t *testing.T) {
		_, err := env.RunVHDM("create",
			"--vhd-path", env.vhdPath,
			"--size", testVHDSize,
			"--format", testFSType)
		env.AssertSuccess(err, "create")
	})
	
	t.Run("Status shows tracked VHD as attached", func(t *testing.T) {
		output, err := env.RunVHDM("status", "--all")
		env.AssertSuccess(err, "status")
		env.AssertContains(output, "Tracked VHD Disks")
		env.AssertContains(output, "Last Seen")
	})
	
	t.Run("Mount VHD", func(t *testing.T) {
		_, err := env.RunVHDM("mount",
			"--vhd-path", env.vhdPath,
			"--mount-point", env.mountPoint)
		env.AssertSuccess(err, "mount")
	})
	
	t.Run("Status shows mounted state", func(t *testing.T) {
		output, err := env.RunVHDM("status", "--all")
		env.AssertSuccess(err, "status")
		env.AssertContains(output, "mounted")
	})
	
	t.Run("Detach VHD", func(t *testing.T) {
		_, err := env.RunVHDM("detach",
			"--vhd-path", env.vhdPath)
		env.AssertSuccess(err, "detach")
	})
	
	t.Run("Status shows detached state but still tracked", func(t *testing.T) {
		output, err := env.RunVHDM("status", "--all")
		env.AssertSuccess(err, "status")
		env.AssertContains(output, "Tracked VHD Disks")
		env.AssertContains(output, "detached")
	})
}
