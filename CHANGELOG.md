# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased] - Go Branch

### Added

#### Core Features
- Full Go implementation of vhdm CLI
- All 11 commands: attach, detach, mount, umount, format, create, delete, resize, status, history, sync
- Shell completion generation for Bash, Zsh, Fish, and PowerShell
- Comprehensive input validation with security checks
- Structured error handling with help text

#### Build System
- Makefile with build, test, install, and lint targets
- Install script for one-command installation
- Version info embedded at build time (version, commit, date)

#### Testing
- 158 unit tests covering validation, tracking, types, and utils
- 30+ integration tests for VHD operations
- Test coverage reporting

#### Compatibility
- Reads/writes same tracking file format as bash version
- Same command-line interface and flags
- Same path format conventions

### Changed
- Rewritten from Bash to Go for better performance and maintainability
- Improved error messages with context and suggestions
- More consistent output formatting

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
