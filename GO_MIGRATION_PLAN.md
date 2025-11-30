# WSL VHD Disk Management - Go Migration Plan

## Executive Summary

This document outlines a comprehensive plan to migrate the bash-based VHD management tool (`vhdm`) to Go. The migration will preserve all existing functionality while improving maintainability, testability, and cross-platform compatibility.

**Current Codebase Statistics:**
- `vhdm.sh`: ~2,937 lines (main CLI)
- `libs/utils.sh`: ~719 lines (utilities, logging, validation)
- `libs/wsl_vhd_mngt.sh`: ~1,410 lines (WSL operations)
- `libs/wsl_vhd_tracking.sh`: ~926 lines (tracking file management)
- `config.sh`: ~176 lines (configuration)
- Tests: 8 test suites, ~100+ test cases

**Estimated Go Codebase:**
- ~4,000-5,000 lines of Go code
- ~2,000 lines of test code

---

## Table of Contents

1. [Migration Goals](#1-migration-goals)
2. [Go Project Structure](#2-go-project-structure)
3. [Phase-by-Phase Migration Plan](#3-phase-by-phase-migration-plan)
4. [Package Design](#4-package-design)
5. [Data Structures](#5-data-structures)
6. [Command Mapping](#6-command-mapping)
7. [External Dependencies](#7-external-dependencies)
8. [Testing Strategy](#8-testing-strategy)
9. [Migration Checklist](#9-migration-checklist)
10. [Risk Assessment](#10-risk-assessment)

---

## 1. Migration Goals

### Primary Goals
1. **Preserve All Functionality**: Every command and feature must work identically
2. **Maintain Architecture**: Keep the 3-layer architecture (Commands → Helpers → Primitives)
3. **Improve Maintainability**: Strong typing, better error handling, easier testing
4. **Single Binary Distribution**: No external script dependencies

### Secondary Goals
1. **Better Error Messages**: Structured error types with context
2. **Concurrent Operations**: Where applicable (e.g., status --all)
3. **Cross-Compilation**: Build for multiple platforms from single source
4. **Embedded Configuration**: Default config with file/env override support

### Non-Goals (Keep Simple)
1. GUI or TUI interface (CLI only)
2. Plugin system
3. Network features
4. Complete rewrite of business logic

---

## 2. Go Project Structure

```
vhdm/
├── cmd/
│   └── vhdm/
│       └── main.go                 # Entry point
├── internal/
│   ├── cli/
│   │   ├── cli.go                  # Root command setup
│   │   ├── attach.go               # attach command
│   │   ├── detach.go               # detach command
│   │   ├── mount.go                # mount command
│   │   ├── umount.go               # umount command
│   │   ├── format.go               # format command
│   │   ├── status.go               # status command
│   │   ├── create.go               # create command
│   │   ├── delete.go               # delete command
│   │   ├── resize.go               # resize command
│   │   ├── history.go              # history command
│   │   └── sync.go                 # sync command
│   ├── config/
│   │   └── config.go               # Configuration management
│   ├── wsl/
│   │   ├── attach.go               # WSL attach/detach operations
│   │   ├── mount.go                # Mount operations
│   │   ├── device.go               # Device detection and queries
│   │   ├── interop.go              # WSL interop check/enable
│   │   └── format.go               # Filesystem formatting
│   ├── tracking/
│   │   ├── tracking.go             # Tracking file management
│   │   ├── mapping.go              # Path→UUID mappings
│   │   └── history.go              # Detach history
│   ├── validation/
│   │   └── validation.go           # Input validation functions
│   ├── logging/
│   │   └── logging.go              # Structured logging
│   └── types/
│       └── types.go                # Shared types and errors
├── pkg/
│   └── utils/
│       ├── path.go                 # Path conversion utilities
│       ├── size.go                 # Size conversion utilities
│       └── table.go                # Table formatting utilities
├── test/
│   ├── integration/
│   │   ├── attach_test.go
│   │   ├── mount_test.go
│   │   └── ...
│   └── testdata/
│       └── ...
├── go.mod
├── go.sum
├── Makefile
└── README.md
```

---

## 3. Phase-by-Phase Migration Plan

### Phase 1: Foundation (Week 1-2)
**Goal**: Establish project structure and core utilities

#### Tasks:
1. [ ] Initialize Go module: `go mod init github.com/user/vhdm`
2. [ ] Create project directory structure
3. [ ] Implement configuration package (`internal/config`)
   - Load from file, environment, defaults
   - All config variables from `config.sh`
4. [ ] Implement validation package (`internal/validation`)
   - `ValidateWindowsPath()`
   - `ValidateUUID()`
   - `ValidateMountPoint()`
   - `ValidateDeviceName()`
   - `ValidateSizeString()`
   - `ValidateFilesystemType()`
5. [ ] Implement logging package (`internal/logging`)
   - Log levels: Debug, Info, Warn, Error, Success
   - Quiet mode support
   - Debug mode support
   - Optional file logging
6. [ ] Implement utility package (`pkg/utils`)
   - `ConvertWindowsToWSLPath()`
   - `ConvertSizeToBytes()`
   - `BytesToHuman()`
   - Table formatting functions
7. [ ] Implement types package (`internal/types`)
   - Custom error types
   - VHD state enums
   - Common structs

**Deliverable**: Core utilities with unit tests

---

### Phase 2: Tracking System (Week 2-3)
**Goal**: Implement persistent tracking file management

#### Tasks:
1. [ ] Define tracking file JSON schema as Go structs
2. [ ] Implement tracking package (`internal/tracking`)
   - `Init()` - Initialize tracking file
   - `SaveMapping()` - Save path→UUID mapping
   - `LookupUUIDByPath()` - Lookup UUID
   - `LookupUUIDByDevName()` - Lookup by device
   - `UpdateMountPoint()` - Update mount point
   - `RemoveMountPoint()` - Clear mount point
   - `RemoveMapping()` - Remove VHD mapping
   - `SaveDetachHistory()` - Save detach event
   - `RemoveDetachHistory()` - Remove history entries
   - `GetDetachHistory()` - Get history
   - `CleanupStaleMappings()` - Remove stale entries
   - `SyncMappingsSilent()` - Auto-sync on startup
3. [ ] Implement atomic file operations (temp file + rename)
4. [ ] Add file locking for concurrent access safety

**Deliverable**: Full tracking system with tests

---

### Phase 3: WSL Operations (Week 3-4)
**Goal**: Implement WSL-specific operations

#### Tasks:
1. [ ] Implement WSL interop package (`internal/wsl/interop.go`)
   - `IsInteropEnabled()`
   - `EnableInterop()`
   - `EnsureInterop()`
2. [ ] Implement device operations (`internal/wsl/device.go`)
   - `GetBlockDevices()` - List block devices
   - `GetDiskUUIDs()` - List all UUIDs
   - `GetUUIDByDevice()` - UUID from device name
   - `DeviceExists()` - Check device exists
   - `CountDynamicVHDs()` - Count non-system disks
   - `FindDynamicVHDUUID()` - Find single VHD UUID
   - `DetectNewDeviceAfterAttach()` - Snapshot-based detection
3. [ ] Implement attach/detach operations (`internal/wsl/attach.go`)
   - `AttachVHD()` - Call wsl.exe --mount
   - `DetachVHD()` - Call wsl.exe --unmount
   - `IsVHDAttached()` - Check attachment state
4. [ ] Implement mount operations (`internal/wsl/mount.go`)
   - `MountVHD()` - Mount by UUID
   - `UnmountVHD()` - Unmount with diagnostics
   - `IsVHDMounted()` - Check mount state
   - `GetMountPoint()` - Get current mount point
   - `CreateMountPoint()` - Create directory
5. [ ] Implement format operations (`internal/wsl/format.go`)
   - `FormatVHD()` - Format with mkfs
   - `CreateVHD()` - Create with qemu-img

**Deliverable**: Complete WSL operations layer with tests

---

### Phase 4: CLI Commands - Part 1 (Week 4-5)
**Goal**: Implement core commands using Cobra

#### Tasks:
1. [ ] Set up Cobra CLI framework (`internal/cli/cli.go`)
   - Root command with global flags (-q, -d, -y)
   - Version command
   - Help command
2. [ ] Implement `status` command
   - --vhd-path, --uuid, --mount-point, --all flags
   - Quiet mode output
   - Table output for verbose mode
3. [ ] Implement `attach` command
   - --vhd-path flag (required)
   - Snapshot-based device detection
   - Tracking file integration
4. [ ] Implement `detach` command
   - --dev-name, --uuid, --vhd-path flags
   - Auto-unmount if mounted
   - History tracking

**Deliverable**: status, attach, detach commands working

---

### Phase 5: CLI Commands - Part 2 (Week 5-6)
**Goal**: Implement mount/unmount commands

#### Tasks:
1. [ ] Implement `mount` command
   - --vhd-path, --mount-point, --dev-name flags
   - Three scenarios (new attach, already attached, by device)
   - Tracking file updates
   - Resource cleanup on failure
2. [ ] Implement `umount` command
   - --vhd-path, --mount-point, --dev-name flags
   - Optional detach with --vhd-path
   - Tracking file updates
3. [ ] Implement `format` command
   - --dev-name, --uuid, --type flags
   - Confirmation prompt
   - UUID change warning

**Deliverable**: mount, umount, format commands working

---

### Phase 6: CLI Commands - Part 3 (Week 6-7)
**Goal**: Implement remaining commands

#### Tasks:
1. [ ] Implement `create` command
   - --vhd-path, --size, --format, --force flags
   - qemu-img integration
   - Optional attach+format workflow
2. [ ] Implement `delete` command
   - --vhd-path, --uuid, --force flags
   - Safety check (must be detached)
3. [ ] Implement `resize` command
   - --mount-point, --size flags
   - Complete workflow: create → migrate → swap
   - File count verification
4. [ ] Implement `history` command
   - --limit, --vhd-path flags
   - Show mappings and detach history
5. [ ] Implement `sync` command
   - --dry-run flag
   - Clean stale mappings and history

**Deliverable**: All commands working

---

### Phase 7: Testing & Polish (Week 7-8)
**Goal**: Comprehensive testing and final polish

#### Tasks:
1. [ ] Unit tests for all packages (target: 80% coverage)
2. [ ] Integration tests for all commands
3. [ ] Port existing bash tests to Go test framework
4. [ ] End-to-end testing with real VHDs
5. [ ] Error message review and improvement
6. [ ] Documentation
   - Update README.md
   - Generate command help docs
7. [ ] Create Makefile with build targets
8. [ ] CI/CD setup (GitHub Actions)

**Deliverable**: Production-ready Go binary

---

## 4. Package Design

### 4.1 Configuration Package

```go
// internal/config/config.go

package config

type Config struct {
    // UI/Display
    Colors ColorConfig

    // Defaults
    DefaultVHDSize      string // "1G"
    DefaultFilesystem   string // "ext4"
    DefaultHistoryLimit int    // 10

    // Validation Limits
    MaxPathLength       int // 4096
    MaxSizeStringLength int // 20
    MaxDeviceNameLength int // 10
    MaxHistoryLimit     int // 50

    // System
    TrackingFile      string // ~/.config/vhdm/vhd_tracking.json
    SleepAfterAttach  time.Duration // 2s
    DetachTimeout     time.Duration // 30s
    AutoSyncMappings  bool // true

    // Runtime
    Quiet bool
    Debug bool
    Yes   bool
}

func Load() (*Config, error)
func (c *Config) Validate() error
```

### 4.2 Validation Package

```go
// internal/validation/validation.go

package validation

import "errors"

var (
    ErrInvalidWindowsPath  = errors.New("invalid Windows path format")
    ErrInvalidUUID         = errors.New("invalid UUID format")
    ErrInvalidMountPoint   = errors.New("invalid mount point format")
    ErrInvalidDeviceName   = errors.New("invalid device name format")
    ErrInvalidSize         = errors.New("invalid size format")
    ErrInvalidFilesystem   = errors.New("invalid filesystem type")
)

func ValidateWindowsPath(path string) error
func ValidateUUID(uuid string) error
func ValidateMountPoint(path string) error
func ValidateDeviceName(name string) error
func ValidateSizeString(size string) error
func ValidateFilesystemType(fsType string) error
```

### 4.3 WSL Package

```go
// internal/wsl/types.go

package wsl

type VHDState int

const (
    StateUnknown VHDState = iota
    StateDetached
    StateAttachedUnformatted
    StateAttachedFormatted
    StateMounted
)

type VHDInfo struct {
    Path       string
    UUID       string
    DeviceName string
    MountPoint string
    FSAvail    string
    FSUse      string
    State      VHDState
}

type AttachResult struct {
    DeviceName string
    UUID       string // May be empty if unformatted
    WasNew     bool   // True if newly attached
}
```

### 4.4 Tracking Package

```go
// internal/tracking/types.go

package tracking

import "time"

type TrackingFile struct {
    Version       string              `json:"version"`
    Mappings      map[string]*Mapping `json:"mappings"`
    DetachHistory []DetachEvent       `json:"detach_history"`
}

type Mapping struct {
    UUID         string    `json:"uuid"`
    LastAttached time.Time `json:"last_attached"`
    MountPoints  string    `json:"mount_points"`
    DevName      string    `json:"dev_name"`
}

type DetachEvent struct {
    Path      string    `json:"path"`
    UUID      string    `json:"uuid"`
    DevName   string    `json:"dev_name"`
    Timestamp time.Time `json:"timestamp"`
}
```

---

## 5. Data Structures

### 5.1 Error Types

```go
// internal/types/errors.go

package types

import "fmt"

// VHDError represents a VHD operation error with context
type VHDError struct {
    Op      string // Operation that failed
    Path    string // VHD path if applicable
    UUID    string // UUID if applicable
    Err     error  // Underlying error
    Help    string // Help text for user
}

func (e *VHDError) Error() string {
    return fmt.Sprintf("%s: %v", e.Op, e.Err)
}

// Sentinel errors
var (
    ErrVHDNotFound        = errors.New("VHD not found")
    ErrVHDNotAttached     = errors.New("VHD not attached")
    ErrVHDNotMounted      = errors.New("VHD not mounted")
    ErrVHDAlreadyAttached = errors.New("VHD already attached")
    ErrVHDAlreadyMounted  = errors.New("VHD already mounted")
    ErrVHDNotFormatted    = errors.New("VHD not formatted")
    ErrMultipleVHDs       = errors.New("multiple VHDs attached")
    ErrInteropDisabled    = errors.New("WSL interop disabled")
)
```

### 5.2 Command Context

```go
// internal/cli/context.go

package cli

import (
    "github.com/user/vhdm/internal/config"
    "github.com/user/vhdm/internal/logging"
    "github.com/user/vhdm/internal/tracking"
    "github.com/user/vhdm/internal/wsl"
)

// AppContext holds shared application state
type AppContext struct {
    Config   *config.Config
    Logger   *logging.Logger
    Tracker  *tracking.Tracker
    WSL      *wsl.Client
}

func NewAppContext() (*AppContext, error)
```

---

## 6. Command Mapping

| Bash Function | Go Package | Go Function/Command |
|---------------|------------|---------------------|
| `show_usage()` | cli | Auto-generated by Cobra |
| `show_status()` | cli/status.go | `runStatus()` |
| `attach_vhd()` | cli/attach.go | `runAttach()` |
| `mount_vhd()` | cli/mount.go | `runMount()` |
| `umount_vhd()` | cli/umount.go | `runUmount()` |
| `detach_vhd()` | cli/detach.go | `runDetach()` |
| `format_vhd_command()` | cli/format.go | `runFormat()` |
| `create_vhd()` | cli/create.go | `runCreate()` |
| `delete_vhd()` | cli/delete.go | `runDelete()` |
| `resize_vhd()` | cli/resize.go | `runResize()` |
| `history_vhd()` | cli/history.go | `runHistory()` |
| `sync_vhd()` | cli/sync.go | `runSync()` |

| Bash Helper | Go Package | Go Function |
|-------------|------------|-------------|
| `wsl_attach_vhd()` | wsl | `(*Client).AttachVHD()` |
| `wsl_detach_vhd()` | wsl | `(*Client).DetachVHD()` |
| `wsl_mount_vhd()` | wsl | `(*Client).MountVHD()` |
| `wsl_umount_vhd()` | wsl | `(*Client).UnmountVHD()` |
| `wsl_is_vhd_attached()` | wsl | `(*Client).IsAttached()` |
| `wsl_is_vhd_mounted()` | wsl | `(*Client).IsMounted()` |
| `wsl_find_uuid_by_path()` | wsl | `(*Client).FindUUIDByPath()` |
| `detect_new_device_after_attach()` | wsl | `(*Client).DetectNewDevice()` |
| `format_vhd()` | wsl | `(*Client).Format()` |
| `wsl_create_vhd()` | wsl | `(*Client).CreateVHD()` |

| Bash Tracking | Go Package | Go Function |
|---------------|------------|-------------|
| `tracking_file_init()` | tracking | `(*Tracker).Init()` |
| `tracking_file_save_mapping()` | tracking | `(*Tracker).SaveMapping()` |
| `tracking_file_lookup_uuid_by_path()` | tracking | `(*Tracker).LookupUUID()` |
| `tracking_file_update_mount_point()` | tracking | `(*Tracker).UpdateMountPoint()` |
| `tracking_file_remove_mapping()` | tracking | `(*Tracker).RemoveMapping()` |
| `tracking_file_save_detach_history()` | tracking | `(*Tracker).SaveDetachHistory()` |

---

## 7. External Dependencies

### Required Go Packages

```go
// go.mod

module github.com/user/vhdm

go 1.21

require (
    github.com/spf13/cobra v1.8.0      // CLI framework
    github.com/spf13/viper v1.18.0     // Configuration
    github.com/fatih/color v1.16.0     // Terminal colors
    github.com/olekukonko/tablewriter v0.0.5  // Table output
)
```

### System Requirements
- Go 1.21+ (for improved generics and error handling)
- WSL2 environment
- External tools (called via exec):
  - `wsl.exe` - VHD attach/detach
  - `lsblk` - Block device info
  - `blkid` - UUID retrieval
  - `mount`/`umount` - Filesystem operations
  - `mkfs.*` - Filesystem formatting
  - `qemu-img` - VHD file creation
  - `rsync` - Data migration (resize)

---

## 8. Testing Strategy

### 8.1 Unit Tests

Each package will have corresponding `*_test.go` files:

```go
// internal/validation/validation_test.go

func TestValidateWindowsPath(t *testing.T) {
    tests := []struct {
        name    string
        path    string
        wantErr bool
    }{
        {"valid path", "C:/VMs/disk.vhdx", false},
        {"valid backslash", "C:\\VMs\\disk.vhdx", false},
        {"missing drive", "/VMs/disk.vhdx", true},
        {"injection attempt", "C:/VMs/$(rm -rf).vhdx", true},
        {"path traversal", "C:/VMs/../../../etc/passwd", true},
    }
    // ...
}
```

### 8.2 Integration Tests

Test complete command workflows:

```go
// test/integration/attach_test.go

func TestAttachWorkflow(t *testing.T) {
    // Setup: Create test VHD
    // Test: Run attach command
    // Verify: Check device attached, tracking updated
    // Cleanup: Detach and remove VHD
}
```

### 8.3 Test Coverage Targets

| Package | Target Coverage |
|---------|-----------------|
| validation | 95% |
| tracking | 90% |
| wsl | 80% |
| cli | 70% |
| utils | 90% |

---

## 9. Migration Checklist

### Pre-Migration
- [ ] Create feature branch: `feature/go-migration`
- [ ] Set up Go development environment
- [ ] Review all bash functionality thoroughly
- [ ] Document any undocumented behavior

### Phase Completion Checklist

#### Phase 1: Foundation
- [ ] Go module initialized
- [ ] Directory structure created
- [ ] Config package complete with tests
- [ ] Validation package complete with tests
- [ ] Logging package complete with tests
- [ ] Utils package complete with tests
- [ ] Types package complete

#### Phase 2: Tracking
- [ ] Tracking file schema defined
- [ ] All tracking functions implemented
- [ ] Atomic file operations working
- [ ] File locking implemented
- [ ] Unit tests passing

#### Phase 3: WSL Operations
- [ ] Interop check/enable working
- [ ] Device operations complete
- [ ] Attach/detach working
- [ ] Mount/unmount working
- [ ] Format operations working
- [ ] All unit tests passing

#### Phase 4-6: CLI Commands
- [ ] Cobra CLI framework set up
- [ ] All 11 commands implemented
- [ ] Global flags working (-q, -d, -y)
- [ ] Quiet mode output correct
- [ ] Error messages helpful
- [ ] All integration tests passing

#### Phase 7: Testing & Polish
- [ ] Unit test coverage ≥80%
- [ ] All integration tests passing
- [ ] Documentation complete
- [ ] Makefile created
- [ ] CI/CD configured
- [ ] Release binaries built

### Post-Migration
- [ ] Performance comparison with bash version
- [ ] User acceptance testing
- [ ] Migration guide written
- [ ] Old bash scripts archived
- [ ] Release announcement

---

## 10. Risk Assessment

### High Risk
| Risk | Mitigation |
|------|------------|
| External tool behavior differences | Extensive integration testing |
| Tracking file format compatibility | Version field, migration script |
| Race conditions in device detection | Add sleep delays, retries |

### Medium Risk
| Risk | Mitigation |
|------|------------|
| Different error messages confuse users | Document changes |
| Missing edge case handling | Port all existing tests |
| Performance regression | Benchmark critical paths |

### Low Risk
| Risk | Mitigation |
|------|------------|
| Go version compatibility | Target stable Go 1.21+ |
| Dependency updates | Use go.sum, periodic updates |

---

## Appendix A: Bash to Go Pattern Mapping

### Argument Parsing

```bash
# Bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        --vhd-path) vhd_path="$2"; shift 2 ;;
    esac
done
```

```go
// Go (Cobra)
cmd.Flags().StringVar(&vhdPath, "vhd-path", "", "VHD file path")
cmd.MarkFlagRequired("vhd-path")
```

### Error Handling

```bash
# Bash
error_exit "Message" 1 "Help text"
```

```go
// Go
return &types.VHDError{
    Op:   "mount",
    Path: vhdPath,
    Err:  err,
    Help: "Help text",
}
```

### Command Execution

```bash
# Bash
output=$(wsl.exe --mount --vhd "$path" --bare 2>&1)
```

```go
// Go
cmd := exec.Command("wsl.exe", "--mount", "--vhd", path, "--bare")
output, err := cmd.CombinedOutput()
```

### JSON Processing

```bash
# Bash
uuid=$(jq -r --arg path "$path" '.mappings[$path].uuid' "$file")
```

```go
// Go
var data TrackingFile
json.Unmarshal(content, &data)
uuid := data.Mappings[path].UUID
```

---

## Appendix B: Timeline Summary

| Week | Phase | Deliverables |
|------|-------|--------------|
| 1-2 | Foundation | Core utilities, validation, logging |
| 2-3 | Tracking | Complete tracking system |
| 3-4 | WSL Ops | WSL operations layer |
| 4-5 | CLI Part 1 | status, attach, detach |
| 5-6 | CLI Part 2 | mount, umount, format |
| 6-7 | CLI Part 3 | create, delete, resize, history, sync |
| 7-8 | Testing | Full test suite, documentation |

**Total Estimated Time: 6-8 weeks**

---

## Next Steps

1. **Review this plan** - Get feedback and approval
2. **Create feature branch** - `git checkout -b feature/go-migration`
3. **Initialize Go module** - `go mod init`
4. **Start Phase 1** - Begin with foundation packages

---

*Document Version: 1.0*
*Created: 2024*
*Author: Migration Team*

