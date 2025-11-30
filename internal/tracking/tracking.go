// Package tracking manages the persistent VHD tracking file.
package tracking

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/rjdinis/vhdm/pkg/utils"
)

type TrackingFile struct {
	Version       string              `json:"version"`
	Mappings      map[string]*Mapping `json:"mappings"`
	DetachHistory []DetachEvent       `json:"detach_history"`
}

type Mapping struct {
	UUID         string `json:"uuid"`
	LastAttached string `json:"last_attached"`
	MountPoints  string `json:"mount_points"`
	DevName      string `json:"dev_name"`
}

type DetachEvent struct {
	Path      string `json:"path"`
	UUID      string `json:"uuid"`
	DevName   string `json:"dev_name"`
	Timestamp string `json:"timestamp"`
}

const (
	trackingVersion   = "1.0"
	maxHistoryEntries = 50
)

type Tracker struct {
	filePath string
	mu       sync.Mutex
}

func New(filePath string) (*Tracker, error) {
	t := &Tracker{filePath: filePath}
	if err := t.Init(); err != nil {
		return nil, err
	}
	return t, nil
}

func (t *Tracker) Init() error {
	t.mu.Lock()
	defer t.mu.Unlock()
	dir := filepath.Dir(t.filePath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return fmt.Errorf("failed to create tracking directory: %w", err)
	}
	if _, err := os.Stat(t.filePath); os.IsNotExist(err) {
		data := &TrackingFile{
			Version:       trackingVersion,
			Mappings:      make(map[string]*Mapping),
			DetachHistory: []DetachEvent{},
		}
		return t.writeFileLocked(data)
	}
	return nil
}

func (t *Tracker) FilePath() string { return t.filePath }

func (t *Tracker) readFileLocked() (*TrackingFile, error) {
	data, err := os.ReadFile(t.filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return &TrackingFile{
				Version:       trackingVersion,
				Mappings:      make(map[string]*Mapping),
				DetachHistory: []DetachEvent{},
			}, nil
		}
		return nil, err
	}
	var tf TrackingFile
	if err := json.Unmarshal(data, &tf); err != nil {
		return nil, fmt.Errorf("failed to parse tracking file: %w", err)
	}
	if tf.Mappings == nil {
		tf.Mappings = make(map[string]*Mapping)
	}
	return &tf, nil
}

func (t *Tracker) writeFileLocked(data *TrackingFile) error {
	content, err := json.MarshalIndent(data, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal tracking data: %w", err)
	}
	tempFile := t.filePath + ".tmp"
	if err := os.WriteFile(tempFile, content, 0644); err != nil {
		return fmt.Errorf("failed to write temp file: %w", err)
	}
	if err := os.Rename(tempFile, t.filePath); err != nil {
		os.Remove(tempFile)
		return fmt.Errorf("failed to rename temp file: %w", err)
	}
	return nil
}

func normalizePath(path string) string {
	return utils.NormalizePath(path)
}

func (t *Tracker) SaveMapping(path, uuid, mountPoints, devName string) error {
	t.mu.Lock()
	defer t.mu.Unlock()
	tf, err := t.readFileLocked()
	if err != nil {
		return err
	}
	normalized := normalizePath(path)
	tf.Mappings[normalized] = &Mapping{
		UUID:         uuid,
		LastAttached: time.Now().UTC().Format(time.RFC3339),
		MountPoints:  mountPoints,
		DevName:      devName,
	}
	return t.writeFileLocked(tf)
}

func (t *Tracker) LookupUUIDByPath(path string) (string, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	tf, err := t.readFileLocked()
	if err != nil {
		return "", err
	}
	normalized := normalizePath(path)
	if mapping, ok := tf.Mappings[normalized]; ok && mapping.UUID != "" {
		return mapping.UUID, nil
	}
	return "", nil
}

func (t *Tracker) LookupPathByUUID(uuid string) (string, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	tf, err := t.readFileLocked()
	if err != nil {
		return "", err
	}
	for path, mapping := range tf.Mappings {
		if mapping.UUID == uuid {
			return path, nil
		}
	}
	return "", nil
}

func (t *Tracker) GetMapping(path string) (*Mapping, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	tf, err := t.readFileLocked()
	if err != nil {
		return nil, err
	}
	normalized := normalizePath(path)
	if mapping, ok := tf.Mappings[normalized]; ok {
		return &Mapping{
			UUID:         mapping.UUID,
			LastAttached: mapping.LastAttached,
			MountPoints:  mapping.MountPoints,
			DevName:      mapping.DevName,
		}, nil
	}
	return nil, nil
}

func (t *Tracker) GetAllMappings() (map[string]*Mapping, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	tf, err := t.readFileLocked()
	if err != nil {
		return nil, err
	}
	result := make(map[string]*Mapping, len(tf.Mappings))
	for k, v := range tf.Mappings {
		result[k] = &Mapping{
			UUID:         v.UUID,
			LastAttached: v.LastAttached,
			MountPoints:  v.MountPoints,
			DevName:      v.DevName,
		}
	}
	return result, nil
}

func (t *Tracker) RemoveMapping(path string) error {
	t.mu.Lock()
	defer t.mu.Unlock()
	tf, err := t.readFileLocked()
	if err != nil {
		return err
	}
	delete(tf.Mappings, normalizePath(path))
	return t.writeFileLocked(tf)
}

func (t *Tracker) SaveDetachHistory(path, uuid, devName string) error {
	t.mu.Lock()
	defer t.mu.Unlock()
	tf, err := t.readFileLocked()
	if err != nil {
		return err
	}
	event := DetachEvent{
		Path:      normalizePath(path),
		UUID:      uuid,
		DevName:   devName,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
	}
	tf.DetachHistory = append([]DetachEvent{event}, tf.DetachHistory...)
	if len(tf.DetachHistory) > maxHistoryEntries {
		tf.DetachHistory = tf.DetachHistory[:maxHistoryEntries]
	}
	return t.writeFileLocked(tf)
}

func (t *Tracker) RemoveDetachHistory(path string) error {
	t.mu.Lock()
	defer t.mu.Unlock()
	tf, err := t.readFileLocked()
	if err != nil {
		return err
	}
	normalized := normalizePath(path)
	var filtered []DetachEvent
	for _, event := range tf.DetachHistory {
		if event.Path != normalized {
			filtered = append(filtered, event)
		}
	}
	tf.DetachHistory = filtered
	return t.writeFileLocked(tf)
}

func (t *Tracker) GetDetachHistory(limit int) ([]DetachEvent, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	tf, err := t.readFileLocked()
	if err != nil {
		return nil, err
	}
	if limit <= 0 || limit > len(tf.DetachHistory) {
		limit = len(tf.DetachHistory)
	}
	return tf.DetachHistory[:limit], nil
}
