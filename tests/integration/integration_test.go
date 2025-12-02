// Package integration provides integration tests for vhdm.
// These tests create actual VHD files and interact with WSL.
//
// To run integration tests:
//   VHDM_INTEGRATION_TESTS=1 go test -v ./tests/integration/...
//
// Requirements:
//   - WSL2 environment
//   - sudo permissions (for mount/format operations)
//   - qemu-img installed
//   - Write access to C:/Anos/VMs/wsl_tests/ (or configure VHDM_TEST_DIR)
package integration

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

const (
	testVHDSize = "100M"
	testFSType  = "ext4"
)

// skipIfNotIntegration skips the test if integration tests are not enabled
func skipIfNotIntegration(t *testing.T) {
	t.Helper()
	if os.Getenv("VHDM_INTEGRATION_TESTS") != "1" {
		t.Skip("Skipping integration test. Set VHDM_INTEGRATION_TESTS=1 to run.")
	}
}

// TestEnvironment holds test resources
type TestEnvironment struct {
	t          *testing.T
	vhdmBinary string
	testDir    string      // WSL path for test directory
	winTestDir string      // Windows path for test directory
	vhdPath    string      // Windows path for VHD
	mountPoint string      // WSL path for mount point
}

// NewTestEnvironment creates a new test environment
func NewTestEnvironment(t *testing.T) *TestEnvironment {
	t.Helper()
	
	// Find vhdm binary
	projectRoot := findProjectRoot(t)
	vhdmBinary := filepath.Join(projectRoot, "vhdm")
	
	if _, err := os.Stat(vhdmBinary); os.IsNotExist(err) {
		t.Fatalf("vhdm binary not found at %s. Run 'go build -o vhdm ./cmd/vhdm' first", vhdmBinary)
	}
	
	// Get test directory from environment or use default
	winTestDir := os.Getenv("VHDM_TEST_DIR")
	if winTestDir == "" {
		// Default to a Windows-native path that exists
		winTestDir = "C:/Anos/VMs/wsl_tests"
	}
	
	// Convert to WSL path
	testDir := convertToWSLPath(t, winTestDir)
	
	// Verify the directory exists
	if _, err := os.Stat(testDir); os.IsNotExist(err) {
		t.Fatalf("Test directory does not exist: %s (WSL: %s). "+
			"Create it or set VHDM_TEST_DIR environment variable.", winTestDir, testDir)
	}
	
	// Create unique test subdirectory
	testSubDir := "go_test_" + time.Now().Format("20060102_150405")
	testDir = filepath.Join(testDir, testSubDir)
	winTestDir = winTestDir + "/" + testSubDir
	
	if err := os.MkdirAll(testDir, 0755); err != nil {
		t.Fatalf("Failed to create test directory: %v", err)
	}
	
	// Create mount point
	mountPoint := filepath.Join(testDir, "mount")
	if err := os.MkdirAll(mountPoint, 0755); err != nil {
		t.Fatalf("Failed to create mount point: %v", err)
	}
	
	// VHD path in Windows format
	vhdPath := winTestDir + "/test_integration.vhdx"
	
	env := &TestEnvironment{
		t:          t,
		vhdmBinary: vhdmBinary,
		testDir:    testDir,
		winTestDir: winTestDir,
		vhdPath:    vhdPath,
		mountPoint: mountPoint,
	}
	
	t.Logf("Test environment:")
	t.Logf("  WSL test dir: %s", testDir)
	t.Logf("  Win test dir: %s", winTestDir)
	t.Logf("  VHD path: %s", vhdPath)
	t.Logf("  Mount point: %s", mountPoint)
	
	// Register cleanup
	t.Cleanup(func() {
		env.Cleanup()
	})
	
	return env
}

// findProjectRoot finds the project root directory
func findProjectRoot(t *testing.T) string {
	t.Helper()
	
	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("Failed to get working directory: %v", err)
	}
	
	for {
		if _, err := os.Stat(filepath.Join(dir, "go.mod")); err == nil {
			return dir
		}
		
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatalf("Could not find project root (go.mod)")
		}
		dir = parent
	}
}

// convertToWSLPath converts a Windows path to WSL path
func convertToWSLPath(t *testing.T, winPath string) string {
	t.Helper()
	
	// Simple conversion: C:/path -> /mnt/c/path
	if len(winPath) >= 2 && winPath[1] == ':' {
		drive := strings.ToLower(string(winPath[0]))
		return "/mnt/" + drive + strings.ReplaceAll(winPath[2:], "\\", "/")
	}
	
	return winPath
}

// RunVHDM runs the vhdm binary with given arguments
func (e *TestEnvironment) RunVHDM(args ...string) (string, error) {
	e.t.Helper()
	
	e.t.Logf("Running: %s %s", e.vhdmBinary, strings.Join(args, " "))
	
	cmd := exec.Command(e.vhdmBinary, args...)
	output, err := cmd.CombinedOutput()
	
	e.t.Logf("Output: %s", string(output))
	
	return string(output), err
}

// RunVHDMQuiet runs vhdm in quiet mode
func (e *TestEnvironment) RunVHDMQuiet(args ...string) (string, error) {
	e.t.Helper()
	return e.RunVHDM(append([]string{"-q"}, args...)...)
}

// Cleanup removes all test resources
func (e *TestEnvironment) Cleanup() {
	e.t.Helper()
	e.t.Log("Cleaning up test environment...")
	
	// Try to unmount and detach (ignore errors)
	e.RunVHDM("umount", "--vhd-path", e.vhdPath)
	
	// Wait a bit for detach to complete
	time.Sleep(1 * time.Second)
	
	// Remove test directory
	if e.testDir != "" {
		os.RemoveAll(e.testDir)
	}
	
	e.t.Log("Cleanup complete")
}

// AssertContains checks if output contains expected string
func (e *TestEnvironment) AssertContains(output, expected string) {
	e.t.Helper()
	if !strings.Contains(output, expected) {
		e.t.Errorf("Output does not contain %q:\n%s", expected, output)
	}
}

// AssertSuccess checks if error is nil
func (e *TestEnvironment) AssertSuccess(err error, context string) {
	e.t.Helper()
	if err != nil {
		e.t.Fatalf("%s failed: %v", context, err)
	}
}
