# VHDM - WSL VHD Disk Manager

A comprehensive command-line tool for managing VHD/VHDX virtual disk files in WSL2.

## Why Use VHDM?

When working with WSL2, you have two options for accessing Windows files: direct Windows mounts (e.g., `/mnt/c/`) or native Linux filesystems on VHD/VHDX disks. **VHDM makes it easy to use VHD disks, which offer significant advantages:**

### Performance Benefits

- **10-100x faster I/O operations** - Native Linux filesystem performance vs. Windows filesystem translation layer
- **No cross-filesystem overhead** - Direct kernel access to ext4/xfs/btrfs instead of translating NTFS calls
- **Better for development** - Compiling code, running tests, and file-intensive operations are dramatically faster

### Symbolic Link Support

- **Full symlink support** - Windows filesystem mounts (`/mnt/c/`) have limited or broken symbolic link support
- **Package manager compatibility** - npm, yarn, pip, and other tools that rely on symlinks work correctly
- **No permission issues** - Avoid the complexity of Windows symlink permissions and Developer Mode requirements

### WSL2 Best Practices

- **Recommended by Microsoft** - Microsoft's official WSL2 documentation recommends storing project files in the Linux filesystem for best performance
- **Native Linux experience** - Work with true Linux filesystem semantics (permissions, case-sensitivity, symlinks)
- **Container-friendly** - Docker and other containerized workflows perform better with native Linux filesystems

**VHDM simplifies VHD management** by providing an intuitive CLI for creating, mounting, resizing, and tracking VHD disks - no more manual `wsl.exe --mount` commands or lost track of which disks are attached where.

## Features

- **Attach/Detach** - Connect VHD files to WSL as block devices
- **Mount/Unmount** - Mount VHD filesystems with automatic attach
- **Create/Delete** - Create new VHD files with optional formatting
- **Format** - Format VHDs with ext4, xfs, btrfs, etc.
- **Resize** - Resize VHDs with data migration, backup, and auto-remount
- **Status** - View all tracked VHDs with their states and last seen timestamps
- **Auto-Tracking** - VHDs are automatically tracked and kept in sync
- **Systemd Services** - Auto-mount VHDs on boot with systemd user services
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

#### Option 1: Using Install Script

```bash
# One-command installation (recommended)
curl -sSL https://raw.githubusercontent.com/rjdinis/vhdm/go/scripts/install.sh | bash
```

This will:
- Clone the repository
- Build the binary
- Install to `/usr/local/bin` (requires sudo)
- Set up shell completions

#### Option 2: Manual Build

```bash
# Clone and build
git clone https://github.com/rjdinis/vhdm.git
cd vhdm
git checkout go

# Build and install
make build
sudo make install
```

**Note:** Installation requires sudo as the binary is installed to `/usr/local/bin`.

### Shell Completions

#### Option 1: Load on shell startup

```bash
# Bash - add to ~/.bashrc
source <(vhdm completion bash)

# Zsh - add to ~/.zshrc  
source <(vhdm completion zsh)

# Fish - add to ~/.config/fish/config.fish
vhdm completion fish | source
```

#### Option 2: Install permanently (system-wide)

```bash
# Bash
sudo mkdir -p /etc/bash_completion.d
vhdm completion bash | sudo tee /etc/bash_completion.d/vhdm >/dev/null

# Zsh
sudo mkdir -p /usr/local/share/zsh/site-functions
vhdm completion zsh | sudo tee /usr/local/share/zsh/site-functions/_vhdm >/dev/null

# Fish
sudo mkdir -p /usr/share/fish/vendor_completions.d
vhdm completion fish | sudo tee /usr/share/fish/vendor_completions.d/vhdm.fish >/dev/null
```

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
| `detach` | Detach VHD from WSL (auto-unmounts if mounted) |
| `mount` | Attach and mount VHD (orchestration) |
| `umount` | Unmount VHD (optionally detach with `--detach`) |
| `format` | Format VHD with filesystem |
| `create` | Create new VHD file |
| `delete` | Delete VHD file |
| `resize` | Resize VHD with data migration (auto-remounts) |
| `status` | Show VHD status, tracking info, and WSL distributions |
| `service` | Manage systemd services for auto-mounting VHDs on boot |
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

### Tracking and Status

```bash
# View all tracked VHDs with their status
vhdm status

# Status shows:
# - WSL Attached Disks (all block devices)
# - Tracked VHD Disks (with Last Seen timestamp)
# - WSL Distributions (from Windows registry)

# VHDs are automatically tracked when attached/mounted
# Non-existent VHDs are automatically removed from tracking
```

### Resize VHD

```bash
# Resize to 20GB (creates backup, auto-remounts)
vhdm resize --vhd-path C:/VMs/disk.vhdx --size 20G -y

# If the VHD was mounted, it will be:
# 1. Unmounted and detached
# 2. Resized with data migration
# 3. Re-attached and re-mounted to the same mount point
```

### Auto-Mount on Boot (Systemd Service)

```bash
# IMPORTANT: Mount the VHD manually first to register its UUID
vhdm mount --vhd-path C:/VMs/data.vhdx --mount-point /mnt/data

# Verify it's tracked (should show UUID)
vhdm status --vhd-path C:/VMs/data.vhdx

# Create a systemd service to auto-mount VHD on boot
# (requires VHD to be tracked with UUID from previous mount)
sudo vhdm service create --vhd-path C:/VMs/data.vhdx --mount-point /mnt/data

# Enable the service to start on boot
sudo vhdm service enable --name vhdm-mount-data

# List all VHD mount services
vhdm service list

# Check service status
vhdm service status --name vhdm-mount-data

# Disable auto-mount on boot
sudo vhdm service disable --name vhdm-mount-data

# Remove the service completely
sudo vhdm service remove --name vhdm-mount-data

# Start service manually (without waiting for boot)
sudo systemctl start vhdm-mount-data.service
```

#### Important: UUID-Based Service Creation

**Why services require VHDs to be mounted first:**

1. **Prevents Race Conditions**: When multiple VHD services start simultaneously at boot, using filesystem UUIDs instead of path-based device detection eliminates race conditions
2. **Deterministic Identification**: Each VHD is identified by its unique UUID, not by detecting new devices
3. **Reliable Parallel Startup**: All VHD services can start concurrently without conflicts
4. **Best Practice Enforcement**: Ensures VHDs are properly formatted and tested before automation

If you try to create a service for an untracked VHD, you'll get step-by-step instructions:
```
Error: service create C:/VMs/disk.vhdx: VHD is not tracked in the system

The VHD must be attached and mounted at least once before creating a service.
This ensures the filesystem UUID is known and prevents device detection race conditions.

To fix this:
  1. Attach and mount the VHD manually first:
     vhdm mount --vhd-path "C:/VMs/disk.vhdx" --mount-point "/mnt/data"
  2. Verify it mounted successfully:
     vhdm status --vhd-path "C:/VMs/disk.vhdx"
  3. Then create the service:
     sudo vhdm service create --vhd-path "C:/VMs/disk.vhdx" --mount-point "/mnt/data"
```

#### Systemd Service Configuration

For system-level services (running as root with `sudo systemctl`), the service file must include:

1. **Windows PATH directories** - Required for `wsl.exe` to be accessible:
   ```ini
   Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/mnt/c/WINDOWS/system32:/mnt/c/WINDOWS"
   ```

2. **Mount dependencies** - Required to ensure Windows drives are mounted before VHD access:
   ```ini
   After=local-fs.target mnt-c.mount
   Requires=mnt-c.mount
   ```

**Example system service file** (created at `/usr/lib/systemd/system/vhdm-mount-data.service`):
```ini
[Unit]
Description=Auto-mount VHD: C:/VMs/data.vhdx
After=local-fs.target mnt-c.mount
Requires=mnt-c.mount
Before=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/mnt/c/WINDOWS/system32:/mnt/c/WINDOWS"
# Uses UUID instead of path for reliable device identification (no race conditions)
ExecStart=/usr/local/bin/vhdm mount --uuid "5c8bc48c-4254-4430-b76a-c495d763d067" --mount-point "/mnt/data"
ExecStop=/usr/local/bin/vhdm umount --mount-point "/mnt/data"
TimeoutStartSec=60
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

> **Note**: Service files are created in `/usr/lib/systemd/system/` (standard location for package-installed services). When you enable a service, systemd automatically creates a symbolic link in `/etc/systemd/system/multi-user.target.wants/` pointing to the service file.

**How UUID-based mounting works:**

When a service starts with `mount --uuid`:
1. **Path lookup**: The VHD path is automatically retrieved from the tracking file using the UUID
2. **Auto-attach**: If the VHD isn't already attached, it's attached using the retrieved path
3. **Mount**: The VHD is mounted to the specified mount point

This means services don't need to know the VHD path - they only need the UUID and mount point.

**Key benefits:**
- `ExecStart` uses `--uuid` instead of `--vhd-path` for deterministic device identification
- Eliminates snapshot-based device detection that fails with concurrent service startup
- Multiple VHD services can start in parallel without conflicts
- VHDs are automatically attached on boot even if not previously attached

After creating or modifying service files:
```bash
sudo systemctl daemon-reload
sudo systemctl enable vhdm-mount-data.service
sudo systemctl start vhdm-mount-data.service
```

> **Note**: Services created with `vhdm service create` automatically include all required configuration (PATH, mount dependencies, UUID-based mounting). Manual editing is not needed.

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

### Install

```bash
sudo make install   # Install to /usr/local/bin (requires sudo)
sudo make uninstall # Remove from /usr/local/bin
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

2. **VHD tracking**: The tool tracks VHDs in `~/.config/vhdm/vhd_tracking.json`
   - VHDs remain tracked even when detached (status shows "detached")
   - Tracking is automatically updated on attach/mount/detach operations
   - Non-existent VHD files are automatically removed from tracking
   - Original path casing is preserved (e.g., `C:/aNOS/VMs/disk.vhdx` not `c:/anos/vms/disk.vhdx`)
   - Paths are normalized internally for case-insensitive matching

3. **UUID changes**: Formatting or resizing a VHD generates a new UUID

4. **Resize behavior**:
   - Creates a backup (`*_bkp.vhdx`) - verify and delete manually
   - If mounted, auto-unmounts before resize and re-mounts after
   - If resize fails, the original VHD is restored to its mount point

5. **Before unmounting**: Ensure no processes are using the mount point:
   ```bash
   sudo lsof +D /mnt/data
   ```

6. **Multiple VHDs**: When multiple VHDs are attached, always specify `--vhd-path` or `--uuid`

7. **Last Seen**: Tracking records when each VHD was last attached/mounted

## Bash Version

The original bash implementation is available on the `main` branch:

```bash
git checkout main
./vhdm.sh --help
```

## License

BSD-3-Clause - See [LICENSE](LICENSE) file.
