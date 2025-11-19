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

# Get list of block device names
# Returns: Array of block device names
wsl_get_block_devices() {
    sudo lsblk -J | jq -r '.blockdevices[].name'
}

# Get list of all disk UUIDs
# Returns: Array of UUIDs
wsl_get_disk_uuids() {
    sudo blkid -s UUID -o value
}

# Find UUID by mount point
# Args: $1 - Mount point path
# Returns: UUID if found, empty string if not found
wsl_find_uuid_by_mountpoint() {
    local mount_point="$1"
    
    if [[ -z "$mount_point" ]]; then
        return 1
    fi
    
    # Get UUID for the device mounted at the specified mount point
    local uuid=$(lsblk -f -J | jq -r --arg MP "$mount_point" '.blockdevices[] | select(.mountpoints != null and .mountpoints != []) | select(.mountpoints[] == $MP) | .uuid' 2>/dev/null | grep -v "null" | head -n 1)
    
    if [[ -n "$uuid" ]]; then
        echo "$uuid"
        return 0
    fi
    
    return 1
}

# Find UUID by checking all attached VHDs for one matching pattern
# This looks for dynamically attached VHDs (typically sd[d-z])
# Returns: First non-system disk UUID found, empty if none
wsl_find_dynamic_vhd_uuid() {
    local all_uuids
    all_uuids=$(wsl_get_disk_uuids)
    
    while IFS= read -r uuid; do
        [[ -z "$uuid" ]] && continue
        
        local dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" '.blockdevices[] | select(.uuid == $UUID) | .name' 2>/dev/null)
        
        if [[ -n "$dev_name" ]]; then
            # Look for dynamically attached disks (usually sd[d-z])
            # Skip system disks (sda, sdb, sdc)
            if [[ "$dev_name" =~ ^sd[d-z]$ ]]; then
                echo "$uuid"
                return 0
            fi
        fi
    done <<< "$all_uuids"
    
    return 1
}

# Create a new VHD file and format it
# Args: $1 - VHD path (Windows path format, e.g., C:/path/to/disk.vhdx)
#       $2 - Size (e.g., 1G, 500M, 10G)
#       $3 - Filesystem type (optional, defaults to ext4)
#       $4 - VHD name for WSL (optional, defaults to "disk")
# Returns: 0 on success, 1 on failure
# Prints: The UUID of the newly created and formatted disk
wsl_create_vhd() {
    local vhd_path_win="$1"
    local size="$2"
    local fs_type="${3:-ext4}"
    local vhd_name="${4:-disk}"
    
    if [[ -z "$vhd_path_win" || -z "$size" ]]; then
        echo "Error: VHD path and size are required" >&2
        return 1
    fi
    
    # Convert Windows path to WSL path for file operations
    local vhd_path_wsl=$(echo "$vhd_path_win" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\|/|g')
    
    # Check if VHD already exists
    if [[ -e "$vhd_path_wsl" ]]; then
        echo "Error: VHD file already exists at $vhd_path_wsl" >&2
        return 1
    fi
    
    # Create parent directory if it doesn't exist
    local vhd_dir=$(dirname "$vhd_path_wsl")
    if [[ ! -d "$vhd_dir" ]]; then
        if ! mkdir -p "$vhd_dir" 2>/dev/null; then
            echo "Error: Failed to create directory $vhd_dir" >&2
            return 1
        fi
    fi
    
    # Ensure qemu-img is installed (check for common package managers)
    if ! command -v qemu-img &> /dev/null; then
        echo "Error: qemu-img is not installed. Please install it first." >&2
        echo "  Arch/Manjaro: sudo pacman -Sy qemu-img" >&2
        echo "  Ubuntu/Debian: sudo apt install qemu-utils" >&2
        echo "  Fedora: sudo dnf install qemu-img" >&2
        return 1
    fi
    
    # Take snapshot of current block devices and UUIDs
    local old_devs=($(wsl_get_block_devices))
    local old_uuids=($(wsl_get_disk_uuids))
    
    # Create the VHD file
    if ! qemu-img create -f vhdx "$vhd_path_wsl" "$size" >/dev/null 2>&1; then
        echo "Error: Failed to create VHD file" >&2
        return 1
    fi
    
    # Attach the VHD to WSL
    if ! wsl_attach_vhd "$vhd_path_win" "$vhd_name"; then
        echo "Error: Failed to attach VHD to WSL" >&2
        rm -f "$vhd_path_wsl"
        return 1
    fi
    
    sleep 2  # Give system time to recognize the device
    
    # Take new snapshot to detect the new device
    local new_devs=($(wsl_get_block_devices))
    
    # Build lookup table for old devices
    declare -A seen_dev
    for dev in "${old_devs[@]}"; do
        seen_dev["$dev"]=1
    done
    
    # Find the new device
    local new_dev=""
    for dev in "${new_devs[@]}"; do
        if [[ -z "${seen_dev[$dev]}" ]]; then
            new_dev="$dev"
            break
        fi
    done
    
    if [[ -z "$new_dev" ]]; then
        echo "Error: Could not detect newly attached device" >&2
        wsl_detach_vhd "$vhd_path_win"
        rm -f "$vhd_path_wsl"
        return 1
    fi
    
    # Format the new device
    if ! sudo mkfs -t "$fs_type" "/dev/$new_dev" >/dev/null 2>&1; then
        echo "Error: Failed to format device /dev/$new_dev with $fs_type" >&2
        wsl_detach_vhd "$vhd_path_win"
        rm -f "$vhd_path_wsl"
        return 1
    fi
    
    sleep 1  # Give system time to update UUID info
    
    # Get the UUID of the newly formatted device
    local new_uuid=$(sudo blkid -s UUID -o value "/dev/$new_dev" 2>/dev/null)
    
    if [[ -z "$new_uuid" ]]; then
        echo "Error: Could not retrieve UUID of newly formatted device" >&2
        wsl_detach_vhd "$vhd_path_win"
        rm -f "$vhd_path_wsl"
        return 1
    fi
    
    # Output the UUID
    echo "$new_uuid"
    return 0
}
