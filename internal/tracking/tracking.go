// Package tracking manages persistent VHD state tracking.
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
			Version:       "1.0",
			Mappings:      make(map[string]types.TrackingEntry),
			DetachHistory: []types.DetachHistoryEntry{},
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

func normalizePath(path string) string {
	return strings.ToLower(strings.ReplaceAll(path, "\\", "/"))
}

// SaveMapping saves or updates a VHD mapping
func (t *Tracker) SaveMapping(path, uuid, mountPoint, devName string) error {
	tf, err := t.read()
	if err != nil {
		return err
	}

	normalized := normalizePath(path)
	entry := types.TrackingEntry{
		UUID:         uuid,
		LastAttached: time.Now().Format(time.RFC3339),
		DeviceName:   devName,
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

// LookupPathByUUID looks up VHD path by UUID
func (t *Tracker) LookupPathByUUID(uuid string) (string, error) {
	tf, err := t.read()
	if err != nil {
		return "", err
	}

	for path, entry := range tf.Mappings {
		if entry.UUID == uuid {
			return path, nil
		}
	}
	return "", nil
}

// LookupPathByDevName looks up VHD path by device name
func (t *Tracker) LookupPathByDevName(devName string) (string, error) {
	tf, err := t.read()
	if err != nil {
		return "", err
	}

	for path, entry := range tf.Mappings {
		if entry.DeviceName == devName {
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

// GetAllPaths returns all tracked VHD paths
func (t *Tracker) GetAllPaths() ([]string, error) {
	tf, err := t.read()
	if err != nil {
		return nil, err
	}

	paths := make([]string, 0, len(tf.Mappings))
	for path := range tf.Mappings {
		paths = append(paths, path)
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

// SaveDetachHistory saves a detach event
func (t *Tracker) SaveDetachHistory(path, uuid, devName string) error {
	tf, err := t.read()
	if err != nil {
		return err
	}

	entry := types.DetachHistoryEntry{
		Path:       normalizePath(path),
		UUID:       uuid,
		DeviceName: devName,
		Timestamp:  time.Now().Format(time.RFC3339),
	}
	
	// Prepend new entry
	tf.DetachHistory = append([]types.DetachHistoryEntry{entry}, tf.DetachHistory...)
	
	// Trim to max 50 entries
	if len(tf.DetachHistory) > 50 {
		tf.DetachHistory = tf.DetachHistory[:50]
	}
	
	return t.write(tf)
}

// RemoveDetachHistory removes detach history for a path
func (t *Tracker) RemoveDetachHistory(path string) error {
	tf, err := t.read()
	if err != nil {
		return err
	}

	normalized := normalizePath(path)
	var filtered []types.DetachHistoryEntry
	for _, entry := range tf.DetachHistory {
		if entry.Path != normalized {
			filtered = append(filtered, entry)
		}
	}
	tf.DetachHistory = filtered
	return t.write(tf)
}

// GetDetachHistory returns recent detach history
func (t *Tracker) GetDetachHistory(limit int) ([]types.DetachHistoryEntry, error) {
	tf, err := t.read()
	if err != nil {
		return nil, err
	}

	if limit <= 0 || limit > len(tf.DetachHistory) {
		return tf.DetachHistory, nil
	}
	return tf.DetachHistory[:limit], nil
}
