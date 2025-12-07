package tracking

import (
	"os"
	"path/filepath"
	"testing"
)

func setupTestTracker(t *testing.T) (*Tracker, func()) {
	t.Helper()

	// Create temp directory
	tmpDir, err := os.MkdirTemp("", "vhdm-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}

	trackingFile := filepath.Join(tmpDir, "vhd_tracking.json")
	tracker, err := New(trackingFile)
	if err != nil {
		os.RemoveAll(tmpDir)
		t.Fatalf("Failed to create tracker: %v", err)
	}

	cleanup := func() {
		os.RemoveAll(tmpDir)
	}

	return tracker, cleanup
}

func TestTrackerInit(t *testing.T) {
	tracker, cleanup := setupTestTracker(t)
	defer cleanup()

	// Verify file was created
	if _, err := os.Stat(tracker.filePath); os.IsNotExist(err) {
		t.Error("Tracking file was not created")
	}

	// Verify we can read it
	tf, err := tracker.read()
	if err != nil {
		t.Errorf("Failed to read tracking file: %v", err)
	}

	if tf.Version != "1.0" {
		t.Errorf("Expected version 1.0, got %s", tf.Version)
	}

	if len(tf.Mappings) != 0 {
		t.Errorf("Expected empty mappings, got %d", len(tf.Mappings))
	}
}

func TestSaveAndLookupMapping(t *testing.T) {
	tracker, cleanup := setupTestTracker(t)
	defer cleanup()

	vhdPath := "C:/VMs/test.vhdx"
	uuid := "761c723c-80c8-41dc-b322-6f04d1160e43"
	mountPoint := "/mnt/test"
	devName := "sdd"

	// Save mapping
	err := tracker.SaveMapping(vhdPath, uuid, mountPoint, devName)
	if err != nil {
		t.Fatalf("SaveMapping failed: %v", err)
	}

	// Lookup by path
	gotUUID, err := tracker.LookupUUIDByPath(vhdPath)
	if err != nil {
		t.Errorf("LookupUUIDByPath failed: %v", err)
	}
	if gotUUID != uuid {
		t.Errorf("Expected UUID %s, got %s", uuid, gotUUID)
	}

	// Lookup by UUID
	gotPath, err := tracker.LookupPathByUUID(uuid)
	if err != nil {
		t.Errorf("LookupPathByUUID failed: %v", err)
	}
	if gotPath != vhdPath {
		t.Errorf("Expected path %s, got %s", vhdPath, gotPath)
	}

	// Lookup by device name
	gotPath, err = tracker.LookupPathByDevName(devName)
	if err != nil {
		t.Errorf("LookupPathByDevName failed: %v", err)
	}
	if gotPath != vhdPath {
		t.Errorf("Expected path %s, got %s", vhdPath, gotPath)
	}
}

func TestPathNormalization(t *testing.T) {
	tracker, cleanup := setupTestTracker(t)
	defer cleanup()

	uuid := "761c723c-80c8-41dc-b322-6f04d1160e43"

	// Save with mixed case and backslashes
	err := tracker.SaveMapping("C:\\VMs\\Test.VHDX", uuid, "", "sdd")
	if err != nil {
		t.Fatalf("SaveMapping failed: %v", err)
	}

	// Lookup with different case and slashes
	tests := []string{
		"C:/VMs/Test.VHDX",
		"c:/vms/test.vhdx",
		"C:\\VMs\\Test.VHDX",
		"c:\\vms\\test.vhdx",
	}

	for _, path := range tests {
		gotUUID, err := tracker.LookupUUIDByPath(path)
		if err != nil {
			t.Errorf("LookupUUIDByPath(%q) failed: %v", path, err)
		}
		if gotUUID != uuid {
			t.Errorf("LookupUUIDByPath(%q) = %q, want %q", path, gotUUID, uuid)
		}
	}
}

func TestGetAllPaths(t *testing.T) {
	tracker, cleanup := setupTestTracker(t)
	defer cleanup()

	// Add multiple VHDs
	paths := []string{
		"C:/VMs/disk1.vhdx",
		"C:/VMs/disk2.vhdx",
		"D:/Data/disk3.vhdx",
	}

	for i, path := range paths {
		err := tracker.SaveMapping(path,
			"00000000-0000-0000-0000-00000000000"+string(rune('0'+i)),
			"", "sd"+string(rune('d'+i)))
		if err != nil {
			t.Fatalf("SaveMapping failed: %v", err)
		}
	}

	// Get all paths
	gotPaths, err := tracker.GetAllPaths()
	if err != nil {
		t.Fatalf("GetAllPaths failed: %v", err)
	}

	if len(gotPaths) != len(paths) {
		t.Errorf("Expected %d paths, got %d", len(paths), len(gotPaths))
	}
}

func TestRemoveMapping(t *testing.T) {
	tracker, cleanup := setupTestTracker(t)
	defer cleanup()

	vhdPath := "C:/VMs/test.vhdx"
	uuid := "761c723c-80c8-41dc-b322-6f04d1160e43"

	// Add and then remove
	tracker.SaveMapping(vhdPath, uuid, "", "sdd")
	err := tracker.RemoveMapping(vhdPath)
	if err != nil {
		t.Fatalf("RemoveMapping failed: %v", err)
	}

	// Verify removed
	gotUUID, err := tracker.LookupUUIDByPath(vhdPath)
	if err != nil {
		t.Errorf("LookupUUIDByPath failed: %v", err)
	}
	if gotUUID != "" {
		t.Errorf("Expected empty UUID after removal, got %s", gotUUID)
	}
}

func TestUpdateMountPoints(t *testing.T) {
	tracker, cleanup := setupTestTracker(t)
	defer cleanup()

	vhdPath := "C:/VMs/test.vhdx"
	uuid := "761c723c-80c8-41dc-b322-6f04d1160e43"

	// Add mapping
	tracker.SaveMapping(vhdPath, uuid, "/mnt/old", "sdd")

	// Update mount points
	err := tracker.UpdateMountPoints(vhdPath, []string{"/mnt/new"})
	if err != nil {
		t.Fatalf("UpdateMountPoints failed: %v", err)
	}

	// Verify update
	entry, err := tracker.GetEntry(vhdPath)
	if err != nil {
		t.Fatalf("GetEntry failed: %v", err)
	}

	if len(entry.MountPoints) != 1 || entry.MountPoints[0] != "/mnt/new" {
		t.Errorf("Expected mount point /mnt/new, got %v", entry.MountPoints)
	}
}

func TestUpdateLastSeen(t *testing.T) {
	tracker, cleanup := setupTestTracker(t)
	defer cleanup()

	vhdPath := "C:/VMs/test.vhdx"
	uuid := "761c723c-80c8-41dc-b322-6f04d1160e43"

	// Add mapping
	tracker.SaveMapping(vhdPath, uuid, "/mnt/test", "sdd")

	// Get initial LastSeen
	entry1, err := tracker.GetEntry(vhdPath)
	if err != nil {
		t.Fatalf("GetEntry failed: %v", err)
	}
	initialLastSeen := entry1.LastSeen

	// Wait a bit and update LastSeen
	// (In real usage there would be time difference)
	err = tracker.UpdateLastSeen(vhdPath)
	if err != nil {
		t.Fatalf("UpdateLastSeen failed: %v", err)
	}

	// Verify LastSeen was updated
	entry2, err := tracker.GetEntry(vhdPath)
	if err != nil {
		t.Fatalf("GetEntry failed: %v", err)
	}

	if entry2.LastSeen == "" {
		t.Error("LastSeen should not be empty after update")
	}

	// UUID should remain unchanged
	if entry2.UUID != uuid {
		t.Errorf("UUID changed: got %s, want %s", entry2.UUID, uuid)
	}

	// LastSeen should be >= initial (they might be same if test runs fast)
	if entry2.LastSeen < initialLastSeen {
		t.Errorf("LastSeen went backwards: got %s, was %s", entry2.LastSeen, initialLastSeen)
	}
}

func TestUpdateLastSeenNonExistent(t *testing.T) {
	tracker, cleanup := setupTestTracker(t)
	defer cleanup()

	// Update LastSeen for non-existent path should not error
	err := tracker.UpdateLastSeen("C:/VMs/nonexistent.vhdx")
	if err != nil {
		t.Errorf("UpdateLastSeen for non-existent path should not error: %v", err)
	}
}

func TestCleanupNonExistent(t *testing.T) {
	tracker, cleanup := setupTestTracker(t)
	defer cleanup()

	// Add some mappings
	tracker.SaveMapping("C:/VMs/exists.vhdx", "11111111-1111-1111-1111-111111111111", "", "sdd")
	tracker.SaveMapping("C:/VMs/missing.vhdx", "22222222-2222-2222-2222-222222222222", "", "sde")
	tracker.SaveMapping("C:/VMs/alsomissing.vhdx", "33333333-3333-3333-3333-333333333333", "", "sdf")

	// Mock fileExists function: only "exists.vhdx" exists
	fileExists := func(path string) bool {
		return path == normalizePath("C:/VMs/exists.vhdx")
	}

	// Run cleanup
	removed, err := tracker.CleanupNonExistent(fileExists)
	if err != nil {
		t.Fatalf("CleanupNonExistent failed: %v", err)
	}

	// Should have removed 2 entries
	if len(removed) != 2 {
		t.Errorf("Expected 2 removed paths, got %d: %v", len(removed), removed)
	}

	// Verify only "exists.vhdx" remains
	paths, err := tracker.GetAllPaths()
	if err != nil {
		t.Fatalf("GetAllPaths failed: %v", err)
	}

	if len(paths) != 1 {
		t.Errorf("Expected 1 path remaining, got %d", len(paths))
	}

	// Verify the remaining path is the one that exists
	uuid, _ := tracker.LookupUUIDByPath("C:/VMs/exists.vhdx")
	if uuid != "11111111-1111-1111-1111-111111111111" {
		t.Errorf("Wrong UUID for remaining path: %s", uuid)
	}

	// Verify removed paths are gone
	uuid, _ = tracker.LookupUUIDByPath("C:/VMs/missing.vhdx")
	if uuid != "" {
		t.Errorf("missing.vhdx should be removed, but got UUID: %s", uuid)
	}
}

func TestCleanupNonExistentNoChanges(t *testing.T) {
	tracker, cleanup := setupTestTracker(t)
	defer cleanup()

	// Add a mapping
	tracker.SaveMapping("C:/VMs/exists.vhdx", "11111111-1111-1111-1111-111111111111", "", "sdd")

	// All files exist
	fileExists := func(path string) bool {
		return true
	}

	// Run cleanup
	removed, err := tracker.CleanupNonExistent(fileExists)
	if err != nil {
		t.Fatalf("CleanupNonExistent failed: %v", err)
	}

	// Should have removed nothing
	if len(removed) != 0 {
		t.Errorf("Expected 0 removed paths, got %d", len(removed))
	}
}

func TestLastSeenFieldInEntry(t *testing.T) {
	tracker, cleanup := setupTestTracker(t)
	defer cleanup()

	vhdPath := "C:/VMs/test.vhdx"
	uuid := "761c723c-80c8-41dc-b322-6f04d1160e43"

	// Save mapping
	tracker.SaveMapping(vhdPath, uuid, "/mnt/test", "sdd")

	// Get entry and verify LastSeen is set
	entry, err := tracker.GetEntry(vhdPath)
	if err != nil {
		t.Fatalf("GetEntry failed: %v", err)
	}

	if entry.LastSeen == "" {
		t.Error("LastSeen should be set automatically by SaveMapping")
	}

	// Verify it looks like an RFC3339 timestamp
	if len(entry.LastSeen) < 19 {
		t.Errorf("LastSeen doesn't look like RFC3339: %s", entry.LastSeen)
	}
}

func TestConcurrentAccess(t *testing.T) {
	tracker, cleanup := setupTestTracker(t)
	defer cleanup()

	// Run multiple goroutines accessing the tracker
	done := make(chan bool)

	for i := 0; i < 10; i++ {
		go func(id int) {
			path := "C:/VMs/disk" + string(rune('0'+id)) + ".vhdx"
			uuid := "00000000-0000-0000-0000-00000000000" + string(rune('0'+id))

			// Write
			tracker.SaveMapping(path, uuid, "", "sdd")

			// Read
			tracker.LookupUUIDByPath(path)
			tracker.GetAllPaths()

			done <- true
		}(i)
	}

	// Wait for all goroutines
	for i := 0; i < 10; i++ {
		<-done
	}

	// Verify file is still valid
	_, err := tracker.read()
	if err != nil {
		t.Errorf("Tracking file corrupted after concurrent access: %v", err)
	}
}
