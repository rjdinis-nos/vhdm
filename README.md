# VHDM - WSL VHD Disk Manager

A comprehensive command-line tool for managing VHD/VHDX virtual disk files in WSL2.

## Features

- **Attach/Detach** - Connect VHD files to WSL as block devices
- **Mount/Unmount** - Mount VHD filesystems with automatic attach
- **Create/Delete** - Create new VHD files with optional formatting
- **Format** - Format VHDs with ext4, xfs, btrfs, etc.
- **Resize** - Resize VHDs with data migration and backup
- **Status** - View all tracked VHDs and their states
- **History** - Track attach/detach events
- **Shell Completion** - Bash, Zsh, Fish, and PowerShell support

## Installation

### Requirements

- **WSL2** on Windows 10/11
- **Go 1.21+** (for building from source)
- **qemu-img** - For VHD creation
- **jq** - For JSON parsing (optional, for bash version)

```bash
# Arch Linux
sudo pacman -S go qemu jq

# Ubuntu/Debian
sudo apt install golang qemu-utils jq
```

### Quick Install

```bash
# Clone and build
git clone https://github.com/rjdinis/vhdm.git
cd vhdm
git checkout go

# Build and install
make build
make install-user  # Installs to ~/go/bin
```

### Install Options

```bash
# Install to /usr/local/bin (requires sudo)
sudo make install

# Install to ~/go/bin (no sudo)
make install-user

# Development - build and add to PATH
make dev
```

### Shell Completions

```bash
# Bash - add to ~/.bashrc
source <(vhdm completion bash)

# Zsh - add to ~/.zshrc  
source <(vhdm completion zsh)

# Fish
vhdm completion fish > ~/.config/fish/completions/vhdm.fish

# PowerShell
vhdm completion powershell | Out-String | Invoke-Expression
```

## Usage

```bash
vhdm [OPTIONS] COMMAND [COMMAND_OPTIONS]
```

### Global Options

| Option | Description |
|--------|-------------|
| `-q, --quiet` | Minimal output (machine-readable) |
| `-d, --debug` | Show all commands being executed |
| `-y, --yes` | Auto-confirm prompts |
| `-h, --help` | Show help |
| `-v, --version` | Show version |

### Commands

| Command | Description |
|---------|-------------|
| `attach` | Attach VHD to WSL as block device |
| `detach` | Detach VHD from WSL |
| `mount` | Attach and mount VHD (orchestration) |
| `umount` | Unmount VHD (and detach with `--vhd-path`) |
| `format` | Format VHD with filesystem |
| `create` | Create new VHD file |
| `delete` | Delete VHD file |
| `resize` | Resize VHD with data migration |
| `status` | Show VHD status |
| `history` | Show tracking history |
| `sync` | Sync tracking file with system state |
| `completion` | Generate shell completion scripts |

## Examples

### Create and Mount a VHD

```bash
# Create a 5GB VHD with ext4 filesystem
vhdm create --vhd-path C:/VMs/data.vhdx --size 5G --format ext4

# Mount to a directory
vhdm mount --vhd-path C:/VMs/data.vhdx --mount-point /mnt/data

# Check status
vhdm status
```

### Step-by-Step Workflow

```bash
# 1. Create VHD file
vhdm create --vhd-path C:/VMs/disk.vhdx --size 10G

# 2. Attach to WSL
vhdm attach --vhd-path C:/VMs/disk.vhdx
# Output shows: Device: /dev/sde

# 3. Format the disk
vhdm format --dev-name sde --type ext4 -y

# 4. Mount
vhdm mount --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data
```

### View Status

```bash
# Show all tracked VHDs
vhdm status

# Quiet mode (for scripts)
vhdm status -q
# Output: c:/vms/disk.vhdx (uuid): mounted

# Debug mode (show commands)
vhdm status -d
```

### Unmount and Detach

```bash
# Unmount only
vhdm umount --mount-point /mnt/data

# Unmount and detach
vhdm umount --vhd-path C:/VMs/disk.vhdx

# Or use detach (auto-unmounts if needed)
vhdm detach --vhd-path C:/VMs/disk.vhdx
```

### History and Tracking

```bash
# View history
vhdm history

# View detach history (last 20 entries)
vhdm history --limit 20

# Sync tracking file (remove stale entries)
vhdm sync

# Dry-run sync
vhdm sync --dry-run
```

### Resize VHD

```bash
# Resize to 20GB (creates backup)
vhdm resize --vhd-path C:/VMs/disk.vhdx --size 20G
```

## Path Formats

| Context | Format | Example |
|---------|--------|---------|
| VHD paths | Windows with forward slashes | `C:/VMs/disk.vhdx` |
| Mount points | Linux absolute path | `/mnt/data` |
| Device names | Without `/dev/` prefix | `sde` |

## Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `VHDM_TRACKING_FILE` | `~/.config/vhdm/vhd_tracking.json` | Tracking file location |
| `VHDM_SLEEP_AFTER_ATTACH` | `2` | Seconds to wait after attach |
| `VHDM_DETACH_TIMEOUT` | `30` | Detach timeout in seconds |
| `VHDM_DEBUG` | `false` | Enable debug mode |
| `VHDM_QUIET` | `false` | Enable quiet mode |

## Development

### Build

```bash
make build          # Build binary
make build-debug    # Build with debug symbols
make clean          # Remove build artifacts
```

### Test

```bash
make test           # Run unit tests
make test-coverage  # Generate coverage report

# Integration tests (requires WSL2, sudo)
VHDM_INTEGRATION_TESTS=1 make test-integration
```

### Code Quality

```bash
make fmt            # Format code
make lint           # Run linters (requires golangci-lint)
```

## Architecture

```
cmd/vhdm/           # Main entry point
internal/
  cli/              # Cobra commands
  config/           # Configuration
  logging/          # Structured logging
  tracking/         # Persistent state tracking
  types/            # Data structures and errors
  validation/       # Input validation
  wsl/              # WSL operations (attach, mount, etc.)
pkg/utils/          # Shared utilities
tests/integration/  # Integration tests
```

## Important Notes

1. **Sudo required**: Mount/unmount operations require sudo permissions

2. **VHD tracking**: The tool tracks VHD→UUID associations in `~/.config/vhdm/vhd_tracking.json`

3. **UUID changes**: Formatting a VHD generates a new UUID

4. **Resize backups**: Resize creates a backup (`*_bkp.vhdx`) - verify and delete manually

5. **Before unmounting**: Ensure no processes are using the mount point:
   ```bash
   sudo lsof +D /mnt/data
   ```

6. **Multiple VHDs**: When multiple VHDs are attached, always specify `--vhd-path` or `--uuid`

## Bash Version

The original bash implementation is available on the `main` branch:

```bash
git checkout main
./vhdm.sh --help
```

## License

BSD-3-Clause - See [LICENSE](LICENSE) file.
