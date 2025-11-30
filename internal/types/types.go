// Package types contains shared types and error definitions for vhdm.
package types

import (
	"errors"
	"fmt"
)

// VHDState represents the state of a VHD
type VHDState int

const (
	StateUnknown VHDState = iota
	StateDetached
	StateAttachedUnformatted
	StateAttachedFormatted
	StateMounted
)

func (s VHDState) String() string {
	switch s {
	case StateDetached:
		return "detached"
	case StateAttachedUnformatted:
		return "attached (unformatted)"
	case StateAttachedFormatted:
		return "attached"
	case StateMounted:
		return "mounted"
	default:
		return "unknown"
	}
}

// VHDInfo contains information about a VHD
type VHDInfo struct {
	Path       string
	UUID       string
	DeviceName string
	MountPoint string
	FSAvail    string
	FSUse      string
	State      VHDState
}

// AttachResult contains the result of an attach operation
type AttachResult struct {
	DeviceName string
	UUID       string
	WasNew     bool
}

// Sentinel errors for VHD operations
var (
	ErrVHDNotFound        = errors.New("VHD not found")
	ErrVHDNotAttached     = errors.New("VHD not attached")
	ErrVHDNotMounted      = errors.New("VHD not mounted")
	ErrVHDAlreadyAttached = errors.New("VHD already attached")
	ErrVHDAlreadyMounted  = errors.New("VHD already mounted")
	ErrVHDNotFormatted    = errors.New("VHD not formatted")
	ErrMultipleVHDs       = errors.New("multiple VHDs attached")
	ErrInteropDisabled    = errors.New("WSL interop disabled")
	ErrDeviceNotFound     = errors.New("device not found")
	ErrMountFailed        = errors.New("mount operation failed")
	ErrUnmountFailed      = errors.New("unmount operation failed")
	ErrFormatFailed       = errors.New("format operation failed")
	ErrDetachTimeout      = errors.New("detach operation timed out")
)

// VHDError represents a VHD operation error with context
type VHDError struct {
	Op   string
	Path string
	UUID string
	Err  error
	Help string
}

func (e *VHDError) Error() string {
	if e.Path != "" {
		return fmt.Sprintf("%s %s: %v", e.Op, e.Path, e.Err)
	}
	if e.UUID != "" {
		return fmt.Sprintf("%s (UUID: %s): %v", e.Op, e.UUID, e.Err)
	}
	return fmt.Sprintf("%s: %v", e.Op, e.Err)
}

func (e *VHDError) Unwrap() error {
	return e.Err
}

// IsAlreadyAttached checks if the error indicates VHD is already attached
func IsAlreadyAttached(err error) bool {
	return errors.Is(err, ErrVHDAlreadyAttached)
}

// IsNotFound checks if the error indicates VHD was not found
func IsNotFound(err error) bool {
	return errors.Is(err, ErrVHDNotFound)
}

// IsMultipleVHDs checks if the error indicates multiple VHDs are attached
func IsMultipleVHDs(err error) bool {
	return errors.Is(err, ErrMultipleVHDs)
}

// NewVHDError creates a new VHDError
func NewVHDError(op, path string, err error, help string) *VHDError {
	return &VHDError{Op: op, Path: path, Err: err, Help: help}
}
