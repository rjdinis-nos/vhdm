# VHDM - WSL VHD Disk Manager

A command-line tool for managing VHD/VHDX files in WSL2.

## Installation

### Requirements
- **WSL 2** on Windows
- **qemu-img** - `sudo pacman -Sy qemu-img` (Arch) or `sudo apt install qemu-utils` (Ubuntu/Debian)
- **jq** - `sudo <package-manager> install jq`
- **rsync** - Usually pre-installed

### Setup
```bash
git clone <repo-url>
cd vhdm
chmod +x vhdm.sh
```

## Usage

```bash
./vhdm.sh [OPTIONS] COMMAND [COMMAND_OPTIONS]
```

### Global Options
- `-q, --quiet` - Minimal output (machine-readable)
- `-d, --debug` - Show all commands being executed
- `-h, --help` - Show help

### Commands

| Command | Description |
|---------|-------------|
| `attach` | Attach VHD to WSL (without mounting) |
| `mount` | Attach and mount VHD |
| `umount` | Unmount VHD (and detach if path provided) |
| `detach` | Detach VHD from WSL |
| `status` | Show VHD status |
| `create` | Create new VHD |
| `delete` | Delete VHD file |
| `format` | Format VHD with filesystem |
| `resize` | Resize VHD (creates backup) |
| `history` | Show tracking history |
| `sync` | Sync tracking file with system |

### Examples

```bash
# Create and format a 5GB VHD
./vhdm.sh create --vhd-path C:/VMs/disk.vhdx --size 5G --format ext4

# Mount VHD
./vhdm.sh mount --vhd-path C:/VMs/disk.vhdx --mount-point /mnt/data

# Check status
./vhdm.sh status --all
./vhdm.sh status --vhd-path C:/VMs/disk.vhdx

# Unmount and detach
./vhdm.sh umount --vhd-path C:/VMs/disk.vhdx

# Resize disk to 10GB
./vhdm.sh resize --mount-point /mnt/data --size 10G

# Delete VHD
./vhdm.sh delete --vhd-path C:/VMs/disk.vhdx --force
```

## Important Notes

1. **Path formats**: Use Windows paths with forward slashes for VHDs: `C:/VMs/disk.vhdx`

2. **Permissions**: Mount/unmount operations require `sudo`

3. **VHD tracking**: The tool automatically tracks VHD→UUID associations in `~/.config/vhdm/vhd_tracking.json`

4. **Resize backups**: Resize creates a backup (`*_bkp.vhdx`) - verify data and delete manually

5. **Before unmounting**: Ensure no processes are using the mount point:
   ```bash
   sudo lsof +D /mnt/data
   ```

6. **UUID changes**: Formatting a VHD generates a new UUID

## License

BSD-3-Clause - See [LICENSE](LICENSE) file.
