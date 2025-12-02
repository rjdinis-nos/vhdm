package types

import (
	"encoding/json"
	"errors"
	"testing"
)

func TestMountPointsUnmarshalJSON(t *testing.T) {
	tests := []struct {
		name    string
		json    string
		want    []string
		wantErr bool
	}{
		// String format (bash script format)
		{"single string", `"/mnt/data"`, []string{"/mnt/data"}, false},
		{"empty string", `""`, []string{}, false},
		{"comma separated", `"/mnt/a,/mnt/b"`, []string{"/mnt/a,/mnt/b"}, false},
		
		// Array format (Go format)
		{"empty array", `[]`, []string{}, false},
		{"single element array", `["/mnt/data"]`, []string{"/mnt/data"}, false},
		{"multiple element array", `["/mnt/a", "/mnt/b"]`, []string{"/mnt/a", "/mnt/b"}, false},
		
		// null is valid (empty mount points)
		{"null", `null`, []string{}, false},
		
		// Invalid
		{"number", `123`, nil, true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var mp MountPoints
			err := json.Unmarshal([]byte(tt.json), &mp)
			
			if (err != nil) != tt.wantErr {
				t.Errorf("MountPoints.UnmarshalJSON() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			
			if !tt.wantErr {
				if len(mp) != len(tt.want) {
					t.Errorf("MountPoints.UnmarshalJSON() got %v, want %v", mp, tt.want)
					return
				}
				for i, v := range mp {
					if v != tt.want[i] {
						t.Errorf("MountPoints.UnmarshalJSON() got %v, want %v", mp, tt.want)
						return
					}
				}
			}
		})
	}
}

func TestMountPointsMarshalJSON(t *testing.T) {
	tests := []struct {
		name string
		mp   MountPoints
		want string
	}{
		{"empty", MountPoints{}, `""`},
		{"single", MountPoints{"/mnt/data"}, `"/mnt/data"`},
		{"multiple", MountPoints{"/mnt/a", "/mnt/b"}, `"/mnt/a,/mnt/b"`},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := json.Marshal(tt.mp)
			if err != nil {
				t.Errorf("MountPoints.MarshalJSON() error = %v", err)
				return
			}
			if string(got) != tt.want {
				t.Errorf("MountPoints.MarshalJSON() = %s, want %s", got, tt.want)
			}
		})
	}
}

func TestTrackingEntryJSON(t *testing.T) {
	// Test full round-trip with JSON format
	jsonData := `{
		"uuid": "761c723c-80c8-41dc-b322-6f04d1160e43",
		"last_seen": "2025-11-30T00:17:08Z",
		"mount_points": "/home/user/mount",
		"dev_name": "sdd"
	}`
	
	var entry TrackingEntry
	if err := json.Unmarshal([]byte(jsonData), &entry); err != nil {
		t.Fatalf("Failed to unmarshal: %v", err)
	}
	
	if entry.UUID != "761c723c-80c8-41dc-b322-6f04d1160e43" {
		t.Errorf("UUID mismatch: got %s", entry.UUID)
	}
	if len(entry.MountPoints) != 1 || entry.MountPoints[0] != "/home/user/mount" {
		t.Errorf("MountPoints mismatch: got %v", entry.MountPoints)
	}
	if entry.DeviceName != "sdd" {
		t.Errorf("DeviceName mismatch: got %s", entry.DeviceName)
	}
	if entry.LastSeen != "2025-11-30T00:17:08Z" {
		t.Errorf("LastSeen mismatch: got %s", entry.LastSeen)
	}
	
	// Re-marshal should preserve fields
	out, err := json.Marshal(entry)
	if err != nil {
		t.Fatalf("Failed to marshal: %v", err)
	}
	
	// Unmarshal again to verify
	var entry2 TrackingEntry
	if err := json.Unmarshal(out, &entry2); err != nil {
		t.Fatalf("Failed to unmarshal re-marshaled: %v", err)
	}
	
	if entry.UUID != entry2.UUID {
		t.Errorf("UUID mismatch after round-trip")
	}
	if entry.LastSeen != entry2.LastSeen {
		t.Errorf("LastSeen mismatch after round-trip")
	}
}

func TestVHDError(t *testing.T) {
	tests := []struct {
		name     string
		err      VHDError
		wantMsg  string
		wantHelp string
	}{
		{
			name:     "with path",
			err:      VHDError{Op: "attach", Path: "C:/test.vhdx", Err: ErrVHDNotFound},
			wantMsg:  "attach C:/test.vhdx: VHD file not found",
			wantHelp: "",
		},
		{
			name:     "without path",
			err:      VHDError{Op: "mount", Err: ErrVHDNotFormatted},
			wantMsg:  "mount: VHD is not formatted",
			wantHelp: "",
		},
		{
			name:     "with help",
			err:      VHDError{Op: "attach", Path: "C:/test.vhdx", Err: ErrVHDNotFound, Help: "Check the path"},
			wantMsg:  "attach C:/test.vhdx: VHD file not found",
			wantHelp: "Check the path",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := tt.err.Error(); got != tt.wantMsg {
				t.Errorf("VHDError.Error() = %q, want %q", got, tt.wantMsg)
			}
			if got := tt.err.HelpText(); got != tt.wantHelp {
				t.Errorf("VHDError.HelpText() = %q, want %q", got, tt.wantHelp)
			}
		})
	}
}

func TestIsAlreadyAttached(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{"already attached error", ErrVHDAlreadyAttached, true},
		{"wrapped already attached", &VHDError{Op: "attach", Err: ErrVHDAlreadyAttached}, true},
		{"not found error", ErrVHDNotFound, false},
		{"generic error", errors.New("some error"), false},
		{"nil error", nil, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsAlreadyAttached(tt.err); got != tt.want {
				t.Errorf("IsAlreadyAttached() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestIsNotAttached(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{"not attached error", ErrVHDNotAttached, true},
		{"wrapped not attached", &VHDError{Op: "detach", Err: ErrVHDNotAttached}, true},
		{"already attached error", ErrVHDAlreadyAttached, false},
		{"not found error", ErrVHDNotFound, false},
		{"generic error", errors.New("some error"), false},
		{"nil error", nil, false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsNotAttached(tt.err); got != tt.want {
				t.Errorf("IsNotAttached() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestVHDState(t *testing.T) {
	// Verify state constants
	states := []VHDState{
		StateNotFound,
		StateDetached,
		StateAttachedUnformatted,
		StateAttachedFormatted,
		StateMounted,
	}
	
	for _, s := range states {
		if s == "" {
			t.Errorf("State constant is empty")
		}
	}
	
	// Verify they are distinct
	seen := make(map[VHDState]bool)
	for _, s := range states {
		if seen[s] {
			t.Errorf("Duplicate state: %s", s)
		}
		seen[s] = true
	}
}

func TestVHDInfoJSON(t *testing.T) {
	// Test VHDInfo with all fields including LastSeen
	info := VHDInfo{
		Path:       "C:/VMs/test.vhdx",
		UUID:       "761c723c-80c8-41dc-b322-6f04d1160e43",
		DeviceName: "sdd",
		MountPoint: "/mnt/test",
		FSAvail:    "10G",
		FSUse:      "50%",
		LastSeen:   "2025-12-01T12:00:00Z",
		State:      StateMounted,
	}
	
	// Marshal to JSON
	data, err := json.Marshal(info)
	if err != nil {
		t.Fatalf("Failed to marshal VHDInfo: %v", err)
	}
	
	// Unmarshal back
	var info2 VHDInfo
	if err := json.Unmarshal(data, &info2); err != nil {
		t.Fatalf("Failed to unmarshal VHDInfo: %v", err)
	}
	
	// Verify all fields
	if info2.Path != info.Path {
		t.Errorf("Path mismatch: got %s, want %s", info2.Path, info.Path)
	}
	if info2.UUID != info.UUID {
		t.Errorf("UUID mismatch: got %s, want %s", info2.UUID, info.UUID)
	}
	if info2.LastSeen != info.LastSeen {
		t.Errorf("LastSeen mismatch: got %s, want %s", info2.LastSeen, info.LastSeen)
	}
	if info2.State != info.State {
		t.Errorf("State mismatch: got %s, want %s", info2.State, info.State)
	}
}

func TestTrackingFileJSON(t *testing.T) {
	// Test TrackingFile structure (no DetachHistory)
	tf := TrackingFile{
		Version: "1.0",
		Mappings: map[string]TrackingEntry{
			"c:/vms/test.vhdx": {
				UUID:        "761c723c-80c8-41dc-b322-6f04d1160e43",
				LastSeen:    "2025-12-01T12:00:00Z",
				MountPoints: []string{"/mnt/test"},
				DeviceName:  "sdd",
			},
		},
	}
	
	// Marshal to JSON
	data, err := json.Marshal(tf)
	if err != nil {
		t.Fatalf("Failed to marshal TrackingFile: %v", err)
	}
	
	// Unmarshal back
	var tf2 TrackingFile
	if err := json.Unmarshal(data, &tf2); err != nil {
		t.Fatalf("Failed to unmarshal TrackingFile: %v", err)
	}
	
	// Verify
	if tf2.Version != "1.0" {
		t.Errorf("Version mismatch: got %s", tf2.Version)
	}
	if len(tf2.Mappings) != 1 {
		t.Errorf("Expected 1 mapping, got %d", len(tf2.Mappings))
	}
	
	entry, ok := tf2.Mappings["c:/vms/test.vhdx"]
	if !ok {
		t.Fatal("Expected mapping for c:/vms/test.vhdx")
	}
	if entry.UUID != "761c723c-80c8-41dc-b322-6f04d1160e43" {
		t.Errorf("UUID mismatch: got %s", entry.UUID)
	}
	if entry.LastSeen != "2025-12-01T12:00:00Z" {
		t.Errorf("LastSeen mismatch: got %s", entry.LastSeen)
	}
}
