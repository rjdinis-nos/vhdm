// Package tracking manages persistent VHD state tracking.
//
// VHD paths are stored in a normalized form (lowercase, forward slashes) as map keys
// for case-insensitive lookups, while the original path casing is preserved in the
// OriginalPath field. This allows consistent tracking across different path variations
// (e.g., C:/VMs/disk.vhdx, c:/vms/disk.vhdx, C:\VMs\disk.vhdx) while displaying
// the original casing in status output.
package tracking

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/rjdinis/vhdm/internal/types"
)

// Tracker manages VHD tracking state
type Tracker struct {
	filePath string
	mu       sync.RWMutex
}

// New creates a new Tracker
func New(filePath string) (*Tracker, error) {
	t := &Tracker{filePath: filePath}
	if err := t.init(); err != nil {
		return nil, err
	}
	return t, nil
}

func (t *Tracker) init() error {
	dir := filepath.Dir(t.filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create tracking directory: %w", err)
	}

	if _, err := os.Stat(t.filePath); os.IsNotExist(err) {
		tf := &types.TrackingFile{
			Version:  "1.0",
			Mappings: make(map[string]types.TrackingEntry),
		}
		return t.write(tf)
	}
	return nil
}

func (t *Tracker) read() (*types.TrackingFile, error) {
	t.mu.RLock()
	defer t.mu.RUnlock()

	data, err := os.ReadFile(t.filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to read tracking file: %w", err)
	}

	var tf types.TrackingFile
	if err := json.Unmarshal(data, &tf); err != nil {
		return nil, fmt.Errorf("failed to parse tracking file: %w", err)
	}

	if tf.Mappings == nil {
		tf.Mappings = make(map[string]types.TrackingEntry)
	}
	return &tf, nil
}

func (t *Tracker) write(tf *types.TrackingFile) error {
	t.mu.Lock()
	defer t.mu.Unlock()

	data, err := json.MarshalIndent(tf, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal tracking file: %w", err)
	}

	tmpFile := t.filePath + ".tmp"
	if err := os.WriteFile(tmpFile, data, 0644); err != nil {
		return fmt.Errorf("failed to write temp file: %w", err)
	}

	if err := os.Rename(tmpFile, t.filePath); err != nil {
		os.Remove(tmpFile)
		return fmt.Errorf("failed to rename temp file: %w", err)
	}
	return nil
}

// normalizePath converts a Windows path to lowercase with forward slashes
// for case-insensitive matching. The original path casing is preserved
// separately in TrackingEntry.OriginalPath.
func normalizePath(path string) string {
	return strings.ToLower(strings.ReplaceAll(path, "\\", "/"))
}

// SaveMapping saves or updates a VHD mapping
func (t *Tracker) SaveMapping(path, uuid, mountPoint, devName string) error {
	tf, err := t.read()
	if err != nil {
		return err
	}

	// Remove any placeholder entries for this UUID (auto-discovered entries)
	// This prevents duplicates when the real path is learned
	for key, entry := range tf.Mappings {
		if entry.UUID == uuid && strings.HasPrefix(key, "unknown-") {
			delete(tf.Mappings, key)
		}
	}

	normalized := normalizePath(path)
	entry := types.TrackingEntry{
		UUID:         uuid,
		LastSeen:     time.Now().Format(time.RFC3339),
		DeviceName:   devName,
		OriginalPath: path, // Preserve original case
	}
	if mountPoint != "" {
		entry.MountPoints = []string{mountPoint}
	}
	tf.Mappings[normalized] = entry

	return t.write(tf)
}

// LookupUUIDByPath looks up UUID by VHD path
func (t *Tracker) LookupUUIDByPath(path string) (string, error) {
	tf, err := t.read()
	if err != nil {
		return "", err
	}

	normalized := normalizePath(path)
	if entry, ok := tf.Mappings[normalized]; ok {
		return entry.UUID, nil
	}
	return "", nil
}

// LookupPathByUUID looks up VHD path by UUID.
// Returns the original path with preserved casing (e.g., C:/aNOS/VMs/disk.vhdx).
func (t *Tracker) LookupPathByUUID(uuid string) (string, error) {
	tf, err := t.read()
	if err != nil {
		return "", err
	}

	for path, entry := range tf.Mappings {
		if entry.UUID == uuid {
			// Return original path if available, fallback to normalized key
			if entry.OriginalPath != "" {
				return entry.OriginalPath, nil
			}
			return path, nil
		}
	}
	return "", nil
}

// LookupPathByDevName looks up VHD path by device name.
// Returns the original path with preserved casing (e.g., C:/aNOS/VMs/disk.vhdx).
func (t *Tracker) LookupPathByDevName(devName string) (string, error) {
	tf, err := t.read()
	if err != nil {
		return "", err
	}

	for path, entry := range tf.Mappings {
		if entry.DeviceName == devName {
			// Return original path if available, fallback to normalized key
			if entry.OriginalPath != "" {
				return entry.OriginalPath, nil
			}
			return path, nil
		}
	}
	return "", nil
}

// LookupDevNameByPath looks up device name by VHD path
func (t *Tracker) LookupDevNameByPath(path string) (string, error) {
	tf, err := t.read()
	if err != nil {
		return "", err
	}

	normalized := normalizePath(path)
	if entry, ok := tf.Mappings[normalized]; ok {
		return entry.DeviceName, nil
	}
	return "", nil
}

// GetEntry gets a tracking entry by path
func (t *Tracker) GetEntry(path string) (types.TrackingEntry, error) {
	tf, err := t.read()
	if err != nil {
		return types.TrackingEntry{}, err
	}

	normalized := normalizePath(path)
	if entry, ok := tf.Mappings[normalized]; ok {
		return entry, nil
	}
	return types.TrackingEntry{}, fmt.Errorf("not found")
}

// GetAllPaths returns all tracked VHD paths.
// Returns original paths with preserved casing (e.g., C:/aNOS/VMs/disk.vhdx).
func (t *Tracker) GetAllPaths() ([]string, error) {
	tf, err := t.read()
	if err != nil {
		return nil, err
	}

	paths := make([]string, 0, len(tf.Mappings))
	for path, entry := range tf.Mappings {
		// Return original path if available, fallback to normalized key
		if entry.OriginalPath != "" {
			paths = append(paths, entry.OriginalPath)
		} else {
			paths = append(paths, path)
		}
	}
	return paths, nil
}

// UpdateMountPoints updates mount points for a VHD
func (t *Tracker) UpdateMountPoints(path string, mountPoints []string) error {
	tf, err := t.read()
	if err != nil {
		return err
	}

	normalized := normalizePath(path)
	if entry, ok := tf.Mappings[normalized]; ok {
		entry.MountPoints = mountPoints
		// Preserve OriginalPath if not set
		if entry.OriginalPath == "" {
			entry.OriginalPath = path
		}
		tf.Mappings[normalized] = entry
		return t.write(tf)
	}
	return nil
}

// RemoveMapping removes a VHD mapping
func (t *Tracker) RemoveMapping(path string) error {
	tf, err := t.read()
	if err != nil {
		return err
	}

	normalized := normalizePath(path)
	delete(tf.Mappings, normalized)
	return t.write(tf)
}

// UpdateLastSeen updates the LastSeen timestamp for a VHD
func (t *Tracker) UpdateLastSeen(path string) error {
	tf, err := t.read()
	if err != nil {
		return err
	}

	normalized := normalizePath(path)
	if entry, ok := tf.Mappings[normalized]; ok {
		entry.LastSeen = time.Now().Format(time.RFC3339)
		// Preserve OriginalPath if not set
		if entry.OriginalPath == "" {
			entry.OriginalPath = path
		}
		tf.Mappings[normalized] = entry
		return t.write(tf)
	}
	return nil
}

// SaveMappingByUUID saves or updates a VHD mapping using only UUID and device info
// when the VHD path is unknown (e.g., for auto-discovered mounted VHDs)
func (t *Tracker) SaveMappingByUUID(uuid, mountPoint, devName string) error {
	tf, err := t.read()
	if err != nil {
		return err
	}

	// Check if UUID already exists in any mapping
	for normalized, entry := range tf.Mappings {
		if entry.UUID == uuid {
			// Update existing entry
			if mountPoint != "" {
				entry.MountPoints = []string{mountPoint}
			}
			if devName != "" {
				entry.DeviceName = devName
			}
			entry.LastSeen = time.Now().Format(time.RFC3339)
			tf.Mappings[normalized] = entry
			return t.write(tf)
		}
	}

	// Create new entry with placeholder path based on UUID
	// This allows partial tracking until the actual path is known
	placeholderPath := fmt.Sprintf("unknown-%s", uuid)
	normalized := normalizePath(placeholderPath)
	entry := types.TrackingEntry{
		UUID:         uuid,
		LastSeen:     time.Now().Format(time.RFC3339),
		DeviceName:   devName,
		OriginalPath: placeholderPath,
	}
	if mountPoint != "" {
		entry.MountPoints = []string{mountPoint}
	}
	tf.Mappings[normalized] = entry

	return t.write(tf)
}

// CleanupNonExistent removes tracked VHDs where the file no longer exists
// Returns the list of removed paths
func (t *Tracker) CleanupNonExistent(fileExists func(string) bool) ([]string, error) {
	tf, err := t.read()
	if err != nil {
		return nil, err
	}

	var removed []string
	for path, entry := range tf.Mappings {
		if !fileExists(path) {
			delete(tf.Mappings, path)
			// Return original path if available for better logging
			if entry.OriginalPath != "" {
				removed = append(removed, entry.OriginalPath)
			} else {
				removed = append(removed, path)
			}
		}
	}

	if len(removed) > 0 {
		if err := t.write(tf); err != nil {
			return nil, err
		}
	}

	return removed, nil
}
