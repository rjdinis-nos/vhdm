#!/bin/bash

# WSL Helper Functions Library
# This file contains reusable functions for managing VHD disks in WSL

# Colors for output
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export BLUE='\033[0;34m'
export NC='\033[0m' # No Color

# Check if a VHD is attached to WSL by UUID
# Args: $1 - UUID of the VHD
# Returns: 0 if attached, 1 if not attached
wsl_is_vhd_attached() {
    local uuid="$1"
    local uuid_check
    
    if [[ -z "$uuid" ]]; then
        echo "Error: UUID is required" >&2
        return 2
    fi
    
    uuid_check=$(lsblk -f -J | jq --arg UUID "$uuid" '.blockdevices[] | select(.uuid == $UUID) | .uuid' 2>/dev/null)
    
    if [[ -n "$uuid_check" ]]; then
        return 0  # VHD is attached
    else
        return 1  # VHD is not attached
    fi
}

# Check if a VHD is mounted to the filesystem
# Args: $1 - UUID of the VHD
# Returns: 0 if mounted, 1 if not mounted
wsl_is_vhd_mounted() {
    local uuid="$1"
    local mountpoint_check
    
    if [[ -z "$uuid" ]]; then
        echo "Error: UUID is required" >&2
        return 2
    fi
    
    mountpoint_check=$(lsblk -f -J | jq --arg UUID "$uuid" '.blockdevices[] | select(.uuid == $UUID) | .mountpoints[]' 2>/dev/null | grep -v "null")
    
    if [[ -n "$mountpoint_check" ]]; then
        return 0  # VHD is mounted
    else
        return 1  # VHD is not mounted
    fi
}

# Get VHD device information
# Args: $1 - UUID of the VHD
# Prints device information to stdout
wsl_get_vhd_info() {
    local uuid="$1"
    local device_name fsavail fsuse mountpoints
    
    if [[ -z "$uuid" ]]; then
        echo "Error: UUID is required" >&2
        return 1
    fi
    
    device_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" '.blockdevices[] | select(.uuid == $UUID) | .name' 2>/dev/null)
    fsavail=$(lsblk -f -J | jq -r --arg UUID "$uuid" '.blockdevices[] | select(.uuid == $UUID) | .fsavail' 2>/dev/null)
    fsuse=$(lsblk -f -J | jq -r --arg UUID "$uuid" '.blockdevices[] | select(.uuid == $UUID) | ."fsuse%"' 2>/dev/null)
    mountpoints=$(lsblk -f -J | jq -r --arg UUID "$uuid" '.blockdevices[] | select(.uuid == $UUID) | .mountpoints[]' 2>/dev/null)
    
    if [[ -n "$device_name" ]]; then
        echo "  Device: /dev/$device_name"
        echo "  Available: ${fsavail:-N/A}"
        echo "  Used: ${fsuse:-N/A}"
        echo "  Mounted at: ${mountpoints:-<not mounted>}"
        return 0
    else
        echo "  No device information available"
        return 1
    fi
}

# Attach a VHD to WSL
# Args: $1 - VHD path (Windows path format)
#       $2 - VHD name (optional, defaults to "disk")
# Returns: 0 on success, 1 on failure
wsl_attach_vhd() {
    local vhd_path="$1"
    local vhd_name="${2:-disk}"
    
    if [[ -z "$vhd_path" ]]; then
        echo "Error: VHD path is required" >&2
        return 1
    fi
    
    if wsl.exe --mount --vhd "$vhd_path" --bare --name "$vhd_name" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Detach a VHD from WSL
# Args: $1 - VHD path (Windows path format)
# Returns: 0 on success, 1 on failure
wsl_detach_vhd() {
    local vhd_path="$1"
    
    if [[ -z "$vhd_path" ]]; then
        echo "Error: VHD path is required" >&2
        return 1
    fi
    
    if wsl.exe --unmount "$vhd_path" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Mount a VHD by UUID to a mount point
# Args: $1 - UUID of the VHD
#       $2 - Mount point path
# Returns: 0 on success, 1 on failure
wsl_mount_vhd_by_uuid() {
    local uuid="$1"
    local mount_point="$2"
    
    if [[ -z "$uuid" || -z "$mount_point" ]]; then
        echo "Error: UUID and mount point are required" >&2
        return 1
    fi
    
    # Create mount point if it doesn't exist
    if [[ ! -d "$mount_point" ]]; then
        mkdir -p "$mount_point" 2>/dev/null
    fi
    
    if sudo mount UUID="$uuid" "$mount_point" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Unmount a VHD from a mount point
# Args: $1 - Mount point path
# Returns: 0 on success, 1 on failure
wsl_unmount_vhd() {
    local mount_point="$1"
    
    if [[ -z "$mount_point" ]]; then
        echo "Error: Mount point is required" >&2
        return 1
    fi
    
    if sudo umount "$mount_point" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Complete mount operation: attach VHD if needed and mount to filesystem
# Args: $1 - VHD path (Windows path format)
#       $2 - UUID of the VHD
#       $3 - Mount point path
#       $4 - VHD name (optional)
# Returns: 0 on success, 1 on failure
wsl_complete_mount() {
    local vhd_path="$1"
    local uuid="$2"
    local mount_point="$3"
    local vhd_name="${4:-disk}"
    
    if [[ -z "$vhd_path" || -z "$uuid" || -z "$mount_point" ]]; then
        echo "Error: VHD path, UUID, and mount point are required" >&2
        return 1
    fi
    
    # Check if already attached
    if ! wsl_is_vhd_attached "$uuid"; then
        # Attach VHD
        if ! wsl_attach_vhd "$vhd_path" "$vhd_name"; then
            return 1
        fi
        sleep 2  # Give system time to recognize the device
    fi
    
    # Check if already mounted
    if ! wsl_is_vhd_mounted "$uuid"; then
        # Mount VHD
        if ! wsl_mount_vhd_by_uuid "$uuid" "$mount_point"; then
            return 1
        fi
    fi
    
    return 0
}

# Complete unmount operation: unmount from filesystem and detach from WSL
# Args: $1 - VHD path (Windows path format)
#       $2 - UUID of the VHD
#       $3 - Mount point path
# Returns: 0 on success, 1 on failure
wsl_complete_unmount() {
    local vhd_path="$1"
    local uuid="$2"
    local mount_point="$3"
    
    if [[ -z "$vhd_path" || -z "$uuid" || -z "$mount_point" ]]; then
        echo "Error: VHD path, UUID, and mount point are required" >&2
        return 1
    fi
    
    # Check if attached
    if ! wsl_is_vhd_attached "$uuid"; then
        return 0  # Nothing to do
    fi
    
    # Unmount from filesystem if mounted
    if wsl_is_vhd_mounted "$uuid"; then
        if ! wsl_unmount_vhd "$mount_point"; then
            return 1
        fi
    fi
    
    # Detach from WSL
    if ! wsl_detach_vhd "$vhd_path"; then
        return 1
    fi
    
    return 0
}
