// Package types defines common data structures and error types.
package types

import (
	"encoding/json"
	"errors"
	"fmt"
	"strings"
)

// VHDState represents the current state of a VHD
type VHDState string

const (
	StateNotFound            VHDState = "not found"
	StateDetached            VHDState = "detached"
	StateAttachedUnformatted VHDState = "attached (unformatted)"
	StateAttachedFormatted   VHDState = "attached"
	StateMounted             VHDState = "mounted"
)

// VHDInfo holds detailed information about a VHD
type VHDInfo struct {
	Path       string   `json:"path,omitempty"`
	UUID       string   `json:"uuid,omitempty"`
	DeviceName string   `json:"deviceName,omitempty"`
	MountPoint string   `json:"mountPoint,omitempty"`
	FSAvail    string   `json:"fsAvail,omitempty"`
	FSUse      string   `json:"fsUse,omitempty"`
	LastSeen   string   `json:"lastSeen,omitempty"`
	State      VHDState `json:"state"`
}

// MountPoints handles both string and array formats for mount_points
type MountPoints []string

func (m *MountPoints) UnmarshalJSON(data []byte) error {
	// Handle null
	if string(data) == "null" {
		*m = []string{}
		return nil
	}

	// Try array first
	var arr []string
	if err := json.Unmarshal(data, &arr); err == nil {
		*m = arr
		return nil
	}

	// Try string
	var s string
	if err := json.Unmarshal(data, &s); err == nil {
		if s != "" {
			*m = []string{s}
		} else {
			*m = []string{}
		}
		return nil
	}

	return fmt.Errorf("mount_points must be string or array")
}

func (m MountPoints) MarshalJSON() ([]byte, error) {
	// Always marshal as string for compatibility with bash script
	if len(m) == 0 {
		return json.Marshal("")
	}
	return json.Marshal(strings.Join(m, ","))
}

// TrackingEntry represents a single entry in the VHD tracking file
type TrackingEntry struct {
	UUID         string      `json:"uuid"`
	LastSeen     string      `json:"last_seen"`
	MountPoints  MountPoints `json:"mount_points"`
	DeviceName   string      `json:"dev_name"`
	OriginalPath string      `json:"original_path,omitempty"` // Preserve original case
}

// TrackingFile represents the structure of the VHD tracking JSON file
type TrackingFile struct {
	Version  string                   `json:"version"`
	Mappings map[string]TrackingEntry `json:"mappings"`
}

// AttachResult holds the result of an attach operation
type AttachResult struct {
	WasNew     bool
	DeviceName string
	UUID       string
}

// Common errors
var (
	ErrVHDNotFound        = errors.New("VHD file not found")
	ErrVHDNotAttached     = errors.New("VHD is not attached")
	ErrVHDAlreadyAttached = errors.New("VHD is already attached")
	ErrVHDNotMounted      = errors.New("VHD is not mounted")
	ErrVHDNotFormatted    = errors.New("VHD is not formatted")
	ErrMultipleVHDs       = errors.New("multiple VHDs attached - specify UUID or path")
	ErrDeviceNotFound     = errors.New("device not found after attach")
	ErrDetachTimeout      = errors.New("detach operation timed out")
)

// IsAlreadyAttached checks if error indicates already attached
func IsAlreadyAttached(err error) bool {
	return errors.Is(err, ErrVHDAlreadyAttached)
}

// IsNotAttached checks if error indicates VHD is not attached
func IsNotAttached(err error) bool {
	return errors.Is(err, ErrVHDNotAttached)
}

// VHDError is a structured error with context
type VHDError struct {
	Op   string
	Path string
	Err  error
	Help string
}

func (e *VHDError) Error() string {
	if e.Path != "" {
		return fmt.Sprintf("%s %s: %v", e.Op, e.Path, e.Err)
	}
	return fmt.Sprintf("%s: %v", e.Op, e.Err)
}

func (e *VHDError) Unwrap() error {
	return e.Err
}

// HelpText returns help text for the error
func (e *VHDError) HelpText() string {
	return e.Help
}
