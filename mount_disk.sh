#!/usr/bin/env bash

# mount_disk.sh
# Ensures a VHD is attached and mounted at the specified location
# Usage: ./mount_disk.sh --mount-point <path> --disk-path <path>

set -e

# Get script directory for sourcing helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/libs/wsl_helpers.sh"

# Initialize variables
MOUNT_POINT=""
DISK_PATH=""
QUIET=false
DEBUG=false

# Export flags for child scripts
export QUIET
export DEBUG

# Show usage
show_usage() {
    cat << EOF
Usage: $0 --mount-point <path> --disk-path <path> [OPTIONS]

Ensures a VHD is attached and mounted at the specified mount point.
If already mounted, no action is taken (idempotent).

Required Arguments:
  --mount-point <path>    Target mount point (e.g., /home/user/disk)
  --disk-path <path>      Path to VHD file (Windows format: C:/path/to/disk.vhdx)

Options:
  -q, --quiet            Suppress verbose output
  -d, --debug            Show all commands before execution
  -h, --help             Show this help message

Examples:
  $0 --mount-point /home/user/disk --disk-path C:/VMs/disk.vhdx
  $0 -q --mount-point /mnt/data --disk-path C:/aNOS/VMs/data.vhdx

Exit Codes:
  0 - Success (disk is mounted)
  1 - Error occurred
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mount-point)
            MOUNT_POINT="$2"
            shift 2
            ;;
        --disk-path)
            DISK_PATH="$2"
            shift 2
            ;;
        -q|--quiet)
            QUIET=true
            export QUIET
            shift
            ;;
        -d|--debug)
            DEBUG=true
            export DEBUG
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$1'" >&2
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$MOUNT_POINT" ]]; then
    echo "Error: --mount-point is required" >&2
    show_usage
    exit 1
fi

if [[ -z "$DISK_PATH" ]]; then
    echo "Error: --disk-path is required" >&2
    show_usage
    exit 1
fi

# Convert Windows path to WSL path for file existence check
WSL_DISK_PATH=$(echo "$DISK_PATH" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\|/|g')

# Check if VHD file exists
if [[ ! -f "$WSL_DISK_PATH" ]]; then
    echo "Error: VHD file not found at $WSL_DISK_PATH" >&2
    exit 1
fi

# Check if already mounted at the specified mount point
if [[ -d "$MOUNT_POINT" ]] && mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    [[ "$QUIET" == "false" ]] && echo "✓ Disk already mounted at $MOUNT_POINT"
    exit 0
fi

[[ "$QUIET" == "false" ]] && echo "Disk not mounted. Checking attachment status..."

# Try to find UUID by path (if already attached)
UUID=$(wsl_find_uuid_by_path "$WSL_DISK_PATH" 2>/dev/null || true)

# If not attached, attach it now
if [[ -z "$UUID" ]]; then
    [[ "$QUIET" == "false" ]] && echo "Attaching VHD: $DISK_PATH"
    
    # Generate a name for the attachment
    VHD_NAME=$(basename "$DISK_PATH" .vhdx)
    VHD_NAME=$(basename "$VHD_NAME" .vhd)
    
    # Capture state before attach
    old_uuids=($(wsl_get_disk_uuids))
    
    # Attach the VHD
    if ! debug_cmd wsl.exe --mount --vhd "$DISK_PATH" --bare --name "$VHD_NAME" 2>&1 | grep -a -v "is already attached" >&2; then
        [[ "$QUIET" == "false" ]] && echo "Note: VHD may already be attached, continuing..."
    fi
    
    # Wait for kernel to recognize the device
    sleep 2
    
    # Find the newly attached UUID
    new_uuids=($(wsl_get_disk_uuids))
    for uuid in "${new_uuids[@]}"; do
        if [[ ! " ${old_uuids[@]} " =~ " ${uuid} " ]]; then
            UUID="$uuid"
            break
        fi
    done
    
    # Fallback: search for dynamic VHD if UUID not found
    if [[ -z "$UUID" ]]; then
        UUID=$(wsl_find_dynamic_vhd_uuid 2>/dev/null || true)
    fi
    
    if [[ -z "$UUID" ]]; then
        echo "Error: Failed to detect UUID after attaching VHD" >&2
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo "✓ VHD attached (UUID: $UUID)"
else
    [[ "$QUIET" == "false" ]] && echo "✓ VHD already attached (UUID: $UUID)"
fi

# Check if already mounted (might be mounted elsewhere)
if wsl_is_vhd_mounted "$UUID"; then
    CURRENT_MOUNT=$(wsl_get_mountpoint_by_uuid "$UUID")
    if [[ "$CURRENT_MOUNT" == "$MOUNT_POINT" ]]; then
        [[ "$QUIET" == "false" ]] && echo "✓ Disk already mounted at $MOUNT_POINT"
        exit 0
    else
        [[ "$QUIET" == "false" ]] && echo "✓ Disk already mounted at $CURRENT_MOUNT"
        exit 0
    fi
fi

# Mount the disk
[[ "$QUIET" == "false" ]] && echo "Mounting disk at $MOUNT_POINT..."

# Create mount point if it doesn't exist
if [[ ! -d "$MOUNT_POINT" ]]; then
    debug_cmd mkdir -p "$MOUNT_POINT"
fi

# Mount by UUID
if ! debug_cmd sudo mount UUID="$UUID" "$MOUNT_POINT"; then
    echo "Error: Failed to mount disk" >&2
    exit 1
fi

[[ "$QUIET" == "false" ]] && echo "✓ Disk successfully mounted at $MOUNT_POINT"
exit 0
