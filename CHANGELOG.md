# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - Go Branch

### Added

#### Core Features
- Full Go implementation of vhdm CLI
- 9 commands: attach, detach, mount, umount, format, create, delete, resize, status
- Shell completion generation for Bash, Zsh, Fish, and PowerShell
- Comprehensive input validation with security checks
- Structured error handling with help text

#### Tracking & Status
- "Last Seen" timestamp for each tracked VHD
- Auto-cleanup of non-existent VHDs from tracking
- Tracking stays in sync automatically (no manual sync needed)
- VHDs remain tracked even when detached (status shows "detached")
- WSL Distributions section showing all registered WSL distros from Windows registry
- Distribution information includes name, base path, and VHD path

#### Resize Improvements
- Auto-unmount and detach before resize if VHD is mounted
- Auto re-mount to original mount point after successful resize
- Restore original VHD to mount point if resize fails

#### Detach Improvements
- Gracefully handles already-detached VHDs (no error)
- Auto-unmounts if VHD is mounted before detaching

### Fixed
- Device name normalization in detach, mount, umount, and format commands
  - Commands now properly handle `--dev-name` with or without `/dev/` prefix
  - Fixed tracking file lookup when using `--dev-name=/dev/sdd` format
  - Device names are normalized after validation for consistent tracking
- VHD path casing preservation in status output
  - Added `original_path` field to tracking entries to preserve original case
  - Status command now displays VHD paths with correct casing (e.g., `C:/aNOS/VMs/disk.vhdx`)
  - Backward compatible: old tracking entries without `original_path` fall back to normalized paths
  - Automatic migration: `original_path` is populated on next attach/mount operation

#### Build System
- Makefile with build, test, install, and lint targets
- Install script for one-command installation
- Version info embedded at build time (version, commit, date)

#### Testing
- Unit tests for tracking (73.8% coverage), types (100%), validation (95.3%)
- Integration tests for VHD operations
- Test coverage reporting

### Changed
- Rewritten from Bash to Go for better performance and maintainability
- Improved error messages with context and suggestions
- More consistent output formatting
- Status output now includes "Last Seen" column

### Removed
- `history` command - replaced by status showing tracked VHDs with Last Seen
- `sync` command - tracking is now always kept in sync automatically
- Detach History table - simplified to just track current VHD states

### Migration from Bash
The Go version is a drop-in replacement for the bash script:

```bash
# Bash version
./vhdm.sh mount --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data

# Go version (same command)
vhdm mount --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data
```

## [1.0.0] - Bash Version (main branch)

### Features
- VHD attach/detach via wsl.exe
- Filesystem mount/unmount
- VHD creation with qemu-img
- Formatting with mkfs
- Resize with data migration
- Persistent tracking in JSON
- Quiet and debug modes
