# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **UUID-based service creation**: Services now use filesystem UUIDs for reliable device identification
  - Eliminates race conditions when multiple VHD services start simultaneously at boot
  - Services require VHDs to be mounted at least once before service creation (ensures UUID is tracked)
  - Clear error messages with step-by-step instructions when VHD is not tracked
  - Multiple VHD services can now start in parallel without conflicts
- **Auto-attach on boot**: Services with `mount --uuid` automatically attach VHDs if not already attached
  - VHDs don't need to be pre-attached when WSL starts
  - Service looks up VHD path from tracking file using UUID
  - Attaches VHD on-demand during service startup

### Changed
- `vhdm service create` now requires VHD to be tracked (have UUID in tracking file)
- Service files use `mount --uuid` instead of `mount --vhd-path` in ExecStart
- Service creation now requires `sudo` (system services only, for security and proper tracking file access)
- **Service file location**: Services now created in `/usr/lib/systemd/system/` (standard package location)
  - Enabled services create symlinks in `/etc/systemd/system/multi-user.target.wants/`
  - Follows systemd conventions for package-installed services

### Fixed
- **Critical: UUID overwrite race condition in mount command**
  - When services with `--uuid` started concurrently, device detection race caused wrong UUIDs to be saved
  - Mount command now skips device detection when UUID is provided (trusts expected UUID)
  - Only performs device detection for truly unknown VHDs (first-time attach without tracking)
  - Verified with concurrent 4-service startup test - all VHDs mount with correct UUIDs
- **Tracking file environment variable**: Service files now include `VHDM_TRACKING_FILE` environment variable
  - Ensures services running as root can access user's tracking file
  - Fixes "UUID not found in tracking file" errors on boot
- **Sudo context tracking file access**: Config now detects `SUDO_USER` and uses original user's home directory
  - Fixes "VHD is not tracked" error when running `sudo vhdm service create`
  - Ensures tracking file is read from correct user directory even under sudo
- **Enhanced error messages**: VHDError help text now displays automatically in CLI output

## [1.1.2] - 2025-12-07

### Fixed
- **Service creation** now includes critical systemd configuration:
  - Automatically adds PATH environment variable with Windows directories
  - Automatically adds mount dependencies (`After=mnt-c.mount`, `Requires=mnt-c.mount`)
  - Generated service files now work reliably on boot without manual editing
  - Prevents `wsl.exe attach failed` errors during boot

### Changed
- `vhdm service create` now generates complete, production-ready service files
- Service files include inline comments explaining Windows PATH and mount requirements

## [1.1.1] - 2025-12-07

### Fixed
- Systemd service configuration documentation updated with critical requirements:
  - Added PATH environment variable requirement for system services (must include `/mnt/c/WINDOWS/system32` for `wsl.exe` access)
  - Added mount dependency requirements (`After=mnt-c.mount`, `Requires=mnt-c.mount`) to ensure Windows drives are mounted before VHD operations
  - Added example system service file configuration
  - Clarified differences between user and system services

### Documentation
- Enhanced README with complete systemd service configuration guide
- Added troubleshooting information for service startup failures
- Included example service file with all required configuration

## [1.1.0] - 2024-12-06 - Go Branch

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
