#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source WSL helper functions
source "$SCRIPT_DIR/libs/wsl_helpers.sh"

# Load environment configuration if .env.test exists
if [[ -f "$SCRIPT_DIR/.env.test" ]]; then
    source "$SCRIPT_DIR/.env.test"
else
    # Default configuration (fallback if .env.test doesn't exist)
    WSL_DISKS_DIR="${WSL_DISKS_DIR:-C:/aNOS/VMs/wsl_test/}"
    VHD_NAME="${VHD_NAME:-disk}"
    VHD_PATH="${VHD_PATH:-${WSL_DISKS_DIR}${VHD_NAME}.vhdx}"
    MOUNT_POINT="${MOUNT_POINT:-/home/$USER/$VHD_NAME}"
fi

# Quiet mode flag
QUIET=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] COMMAND [COMMAND_OPTIONS]"
    echo
    echo "Options:"
    echo "  -q, --quiet  - Run in quiet mode (minimal output)"
    echo
    echo "Commands:"
    echo "  mount [OPTIONS]          - Attach and mount the VHD disk"
    echo "  umount [OPTIONS]         - Unmount and detach the VHD disk"
    echo "  status [OPTIONS]         - Show current VHD disk status"
    echo "  create [OPTIONS]         - Create a new VHD disk"
    echo "  delete [OPTIONS]         - Delete a VHD disk file"
    echo
    echo "Mount Command Options:"
    echo "  --path PATH              - VHD file path (Windows format)"
    echo "  --mount-point PATH       - Mount point path"
    echo "  --name NAME              - VHD name for WSL attachment"
    echo
    echo "Umount Command Options:"
    echo "  --path PATH              - VHD file path (Windows format, UUID will be discovered)"
    echo "  --uuid UUID              - VHD UUID (optional if path or mount-point provided)"
    echo "  --mount-point PATH       - Mount point path (UUID will be discovered)"
    echo "  Note: Provide at least one option. UUID will be auto-discovered when possible."
    echo
    echo "Status Command Options:"
    echo "  --path PATH              - VHD file path (Windows format, UUID will be discovered)"
    echo "  --uuid UUID              - VHD UUID (optional if path or mount-point provided)"
    echo "  --mount-point PATH       - Mount point path (UUID will be discovered)"
    echo "  --all                    - Show all attached VHDs"
    echo
    echo "Create Command Options:"
    echo "  --path PATH              - VHD file path (Windows format, e.g., C:/path/disk.vhdx)"
    echo "  --size SIZE              - VHD size (e.g., 1G, 500M, 10G) [default: 1G]"
    echo "  --name NAME              - VHD name for WSL attachment [default: share]"
    echo "  --mount-point PATH       - Mount point path [default: /home/\$USER/share]"
    echo "  --filesystem TYPE        - Filesystem type (ext4, ext3, xfs, etc.) [default: ext4]"
    echo
    echo "Delete Command Options:"
    echo "  --path PATH              - VHD file path (Windows format, UUID will be discovered)"
    echo "  --uuid UUID              - VHD UUID (optional if path provided)"
    echo "  --force                  - Skip confirmation prompt"
    echo "  Note: VHD must be unmounted and detached before deletion."
    echo
    echo "Examples:"
    echo "  $0 mount --path C:/VMs/disk.vhdx --mount-point /mnt/data"
    echo "  $0 umount --path C:/VMs/disk.vhdx"
    echo "  $0 umount --mount-point /mnt/data"
    echo "  $0 umount --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293"
    echo "  $0 status --path C:/VMs/disk.vhdx"
    echo "  $0 status --all"
    echo "  $0 create --path C:/VMs/disk.vhdx --size 5G --name mydisk"
    echo "  $0 delete --path C:/VMs/disk.vhdx"
    echo "  $0 delete --path C:/VMs/disk.vhdx --force"
    echo "  $0 -q status --all"
    echo
    exit 0
}

# Function to show status
show_status() {
    # Parse status command arguments
    local status_path=""
    local status_uuid=""
    local status_mount_point=""
    local show_all=false
    
    # If no arguments, show help
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 status [OPTIONS]"
        echo
        echo "Options:"
        echo "  --path PATH         Show status for specific VHD path (UUID auto-discovered)"
        echo "  --uuid UUID         Show status for specific UUID"
        echo "  --mount-point PATH  Show status for specific mount point (UUID auto-discovered)"
        echo "  --all               Show all attached VHDs"
        echo
        echo "Examples:"
        echo "  $0 status --all"
        echo "  $0 status --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293"
        echo "  $0 status --path C:/VMs/disk.vhdx"
        echo "  $0 status --mount-point /mnt/data"
        return 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                status_path="$2"
                shift 2
                ;;
            --uuid)
                status_uuid="$2"
                shift 2
                ;;
            --mount-point)
                status_mount_point="$2"
                shift 2
                ;;
            --all)
                show_all=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown status option '$1'${NC}"
                echo
                show_usage
                ;;
        esac
    done
    
    # Try to find UUID if not provided
    if [[ -z "$status_uuid" ]]; then
        # If path is provided, check if VHD file exists first
        if [[ -n "$status_path" ]]; then
            local vhd_path_wsl=$(echo "$status_path" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\|/|g')
            
            if [[ ! -e "$vhd_path_wsl" ]]; then
                echo -e "${RED}[✗] VHD file not found${NC}"
                echo
                echo "VHD file does not exist at: $status_path"
                echo "  (WSL path: $vhd_path_wsl)"
                echo
                echo "Suggestions:"
                echo "  1. Check the file path is correct"
                echo "  2. Create a new VHD: $0 create --path $status_path --size <size>"
                echo "  3. See all attached VHDs: $0 status --all"
                
                [[ "$QUIET" == "true" ]] && echo "not found"
                return 1
            fi
            
            # File exists, try to find UUID by path
            status_uuid=$(wsl_find_uuid_by_path "$status_path")
            if [[ -n "$status_uuid" ]]; then
                [[ "$QUIET" == "false" ]] && echo "Found dynamic VHD UUID: $status_uuid"
                [[ "$QUIET" == "false" ]] && echo
            fi
        # Try to find UUID by mount point if provided
        elif [[ -n "$status_mount_point" ]]; then
            status_uuid=$(wsl_find_uuid_by_mountpoint "$status_mount_point")
            if [[ -n "$status_uuid" ]]; then
                [[ "$QUIET" == "false" ]] && echo "Found UUID by mount point: $status_uuid"
                [[ "$QUIET" == "false" ]] && echo
            fi
        fi
    fi
    
    # If --all flag, show all attached VHDs
    if [[ "$show_all" == "true" ]]; then
        [[ "$QUIET" == "false" ]] && echo "========================================"
        [[ "$QUIET" == "false" ]] && echo "  All Attached VHD Disks"
        [[ "$QUIET" == "false" ]] && echo "========================================"
        
        local all_uuids
        all_uuids=$(wsl_get_disk_uuids)
        
        if [[ -z "$all_uuids" ]]; then
            [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] No VHDs attached to WSL${NC}"
            [[ "$QUIET" == "true" ]] && echo "No attached VHDs"
        else
            while IFS= read -r uuid; do
                [[ "$QUIET" == "false" ]] && echo
                [[ "$QUIET" == "false" ]] && echo "UUID: $uuid"
                [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$uuid"
                
                if wsl_is_vhd_mounted "$uuid"; then
                    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] Status: Attached and Mounted${NC}"
                    [[ "$QUIET" == "true" ]] && echo "$uuid: attached,mounted"
                else
                    [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] Status: Attached but not mounted${NC}"
                    [[ "$QUIET" == "true" ]] && echo "$uuid: attached"
                fi
                [[ "$QUIET" == "false" ]] && echo "----------------------------------------"
            done <<< "$all_uuids"
        fi
        [[ "$QUIET" == "false" ]] && echo "========================================"
        return 0
    fi
    
    # If no UUID found after all lookup attempts, report error with suggestions
    if [[ -z "$status_uuid" ]]; then
        echo -e "${RED}[✗] Unable to find VHD${NC}"
        echo
        
        if [[ -n "$status_mount_point" ]]; then
            echo "No VHD is currently mounted at: $status_mount_point"
            echo
            echo "Suggestions:"
            echo "  1. Check if the mount point exists: ls -ld $status_mount_point"
            echo "  2. Verify VHD is mounted: mount | grep $status_mount_point"
            echo "  3. See all attached VHDs: $0 status --all"
            echo "  4. Mount the VHD first: $0 mount --path <path> --mount-point $status_mount_point"
        elif [[ -n "$status_path" ]]; then
            # Convert to WSL path to check if file exists
            local vhd_path_wsl=$(echo "$status_path" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\|/|g')
            
            if [[ ! -e "$vhd_path_wsl" ]]; then
                echo "VHD file not found at: $status_path"
                echo
                echo "Suggestions:"
                echo "  1. Check the file path is correct"
                echo "  2. Create a new VHD: $0 create --path $status_path"
            else
                echo "VHD file exists at: $status_path"
                echo "But it is not currently attached to WSL."
                echo
                echo "Suggestions:"
                echo "  1. Mount the VHD: $0 mount --path $status_path"
                echo "  2. See all attached VHDs: $0 status --all"
            fi
        else
            echo "No UUID, path, or mount point specified."
            echo
            echo "Suggestions:"
            echo "  1. Provide a UUID: $0 status --uuid <uuid>"
            echo "  2. Provide a path: $0 status --path <path>"
            echo "  3. Provide a mount point: $0 status --mount-point <path>"
            echo "  4. See all attached VHDs: $0 status --all"
        fi
        
        [[ "$QUIET" == "true" ]] && echo "not found"
        return 1
    fi
    
    # Show status for specific VHD
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Disk Status"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ -n "$status_path" ]] && [[ "$QUIET" == "false" ]] && echo "  Path: $status_path"
    [[ -n "$status_uuid" ]] && [[ "$QUIET" == "false" ]] && echo "  UUID: $status_uuid"
    [[ -n "$status_mount_point" ]] && [[ "$QUIET" == "false" ]] && echo "  Mount Point: $status_mount_point"
    [[ "$QUIET" == "false" ]] && echo
    
    if wsl_is_vhd_attached "$status_uuid"; then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD is attached to WSL${NC}"
        [[ "$QUIET" == "false" ]] && echo
        [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$status_uuid"
        [[ "$QUIET" == "false" ]] && echo
        
        if wsl_is_vhd_mounted "$status_uuid"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD is mounted${NC}"
            [[ "$QUIET" == "true" ]] && echo "$status_path ($status_uuid): attached,mounted"
        else
            [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is attached but not mounted${NC}"
            [[ "$QUIET" == "true" ]] && echo "$status_path ($status_uuid): attached"
        fi
    else
        [[ "$QUIET" == "false" ]] && echo -e "${RED}[✗] VHD not found${NC}"
        [[ "$QUIET" == "false" ]] && echo "The VHD with UUID $status_uuid is not currently in WSL."
        [[ "$QUIET" == "true" ]] && echo "$status_path ($status_uuid): not found"
    fi
    [[ "$QUIET" == "false" ]] && echo "========================================"
}

# Function to mount VHD
mount_vhd() {
    # Parse mount command arguments
    local mount_path="$VHD_PATH"
    local mount_point="$MOUNT_POINT"
    local mount_name="$VHD_NAME"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                mount_path="$2"
                shift 2
                ;;
            --mount-point)
                mount_point="$2"
                shift 2
                ;;
            --name)
                mount_name="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Error: Unknown mount option '$1'${NC}"
                echo
                show_usage
                ;;
        esac
    done
    
    # Convert Windows path to WSL path to check if VHD exists
    local vhd_path_wsl=$(echo "$mount_path" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\|/|g')
    if [[ ! -e "$vhd_path_wsl" ]]; then
        echo -e "${RED}[✗] VHD file does not exist at $mount_path${NC}"
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Disk Mount Operation"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo
    
    # Take snapshot of current UUIDs and block devices before attaching
    local old_uuids=($(wsl_get_disk_uuids))
    local old_devs=($(wsl_get_block_devices))
    
    # Try to attach the VHD (will succeed if not attached, fail silently if already attached)
    local mount_uuid=""
    local newly_attached=false
    
    if wsl_attach_vhd "$mount_path" "$mount_name" 2>/dev/null; then
        newly_attached=true
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD attached successfully${NC}"
        sleep 2  # Give the system time to recognize the device
        
        # Take new snapshot
        local new_uuids=($(wsl_get_disk_uuids))
        local new_devs=($(wsl_get_block_devices))
        
        # Build lookup tables for old UUIDs and devices
        declare -A seen_uuid
        for uuid in "${old_uuids[@]}"; do
            seen_uuid["$uuid"]=1
        done
        declare -A seen_dev
        for dev in "${old_devs[@]}"; do
            seen_dev["$dev"]=1
        done
        
        # Find the new UUID
        for uuid in "${new_uuids[@]}"; do
            if [[ -z "${seen_uuid[$uuid]}" ]]; then
                mount_uuid="$uuid"
                break
            fi
        done
        
        # Find the new device
        local new_dev=""
        for dev in "${new_devs[@]}"; do
            if [[ -z "${seen_dev[$dev]}" ]]; then
                new_dev="$dev"
                break
            fi
        done
        
        if [[ -z "$mount_uuid" ]]; then
            echo -e "${RED}[✗] Failed to detect UUID of attached VHD${NC}"
            exit 1
        fi
        [[ "$QUIET" == "false" ]] && echo "  Detected UUID: $mount_uuid"
        [[ "$QUIET" == "false" ]] && echo "  Detected Device: /dev/$new_dev"
    else
        # VHD might already be attached, try to find it
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD appears to be already attached, searching for UUID...${NC}"
        
        # Get the VHD filename to help identify it
        local vhd_filename=$(basename "$vhd_path_wsl")
        
        # Try to find UUID by checking which device was mounted most recently that isn't a system disk
        # We'll look for devices that match the VHD name in WSL mount info
        for uuid in "${old_uuids[@]}"; do
            local dev_name=$(lsblk -f -J | jq -r --arg UUID "$uuid" '.blockdevices[] | select(.uuid == $UUID) | .name' 2>/dev/null)
            if [[ -n "$dev_name" ]]; then
                # Skip obvious system disks (typically sda, sdb, sdc for WSL system)
                # Look for dynamically attached disks (usually sd[d-z])
                if [[ "$dev_name" =~ ^sd[d-z]$ ]]; then
                    mount_uuid="$uuid"
                    [[ "$QUIET" == "false" ]] && echo "  Found UUID: $mount_uuid (device: /dev/$dev_name)"
                    break
                fi
            fi
        done
        
        if [[ -z "$mount_uuid" ]]; then
            echo -e "${RED}[✗] Could not detect UUID of VHD. It may already be attached as a system disk.${NC}"
            echo "Try running with --uuid parameter on status command to find the correct UUID."
            exit 1
        fi
    fi
    
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$mount_uuid"
    [[ "$QUIET" == "false" ]] && echo
    
    # Check if already mounted
    if wsl_is_vhd_mounted "$mount_uuid"; then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD is already mounted${NC}"
        [[ "$QUIET" == "false" ]] && echo "Nothing to do."
    else
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is attached but not mounted${NC}"
        
        # Create mount point if it doesn't exist
        if [[ ! -d "$mount_point" ]]; then
            [[ "$QUIET" == "false" ]] && echo "Creating mount point: $mount_point"
            mkdir -p "$mount_point"
        fi
        
        [[ "$QUIET" == "false" ]] && echo "Mounting VHD to $mount_point..."
        if wsl_mount_vhd_by_uuid "$mount_uuid" "$mount_point"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD mounted successfully${NC}"
        else
            echo -e "${RED}[✗] Failed to mount VHD${NC}"
            exit 1
        fi
    fi

    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$mount_uuid"
    
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  Mount operation completed"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if wsl_is_vhd_mounted "$mount_uuid"; then
            echo "$mount_path ($mount_uuid): attached,mounted"
        else
            echo "$mount_path ($mount_uuid): mount failed"
        fi
    fi
}

# Function to unmount VHD
umount_vhd() {
    # Parse umount command arguments
    local umount_path="$VHD_PATH"
    local umount_uuid=""
    local umount_point="$MOUNT_POINT"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                umount_path="$2"
                shift 2
                ;;
            --uuid)
                umount_uuid="$2"
                shift 2
                ;;
            --mount-point)
                umount_point="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Error: Unknown umount option '$1'${NC}"
                echo
                show_usage
                ;;
        esac
    done
    
    # Try to discover UUID if not provided
    if [[ -z "$umount_uuid" ]]; then
        if [[ -n "$umount_path" ]]; then
            # Try to find UUID by path
            umount_uuid=$(wsl_find_uuid_by_path "$umount_path")
            if [[ -n "$umount_uuid" ]]; then
                [[ "$QUIET" == "false" ]] && echo "Discovered UUID from path: $umount_uuid"
                [[ "$QUIET" == "false" ]] && echo
            fi
        elif [[ -n "$umount_point" ]]; then
            # Try to find UUID by mount point
            umount_uuid=$(wsl_find_uuid_by_mountpoint "$umount_point")
            if [[ -n "$umount_uuid" ]]; then
                [[ "$QUIET" == "false" ]] && echo "Discovered UUID from mount point: $umount_uuid"
                [[ "$QUIET" == "false" ]] && echo
            fi
        fi
    fi
    
    # If UUID still not found, report error
    if [[ -z "$umount_uuid" ]]; then
        echo -e "${RED}[✗] Unable to identify VHD${NC}"
        echo
        echo "Could not discover UUID. Please provide one of:"
        echo "  --uuid UUID           Explicit UUID"
        echo "  --path PATH           VHD file path (will attempt discovery)"
        echo "  --mount-point PATH    Mount point (will attempt discovery)"
        echo
        echo "To find UUID, run: $0 status --all"
        [[ "$QUIET" == "true" ]] && echo "uuid not found"
        return 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Disk Unmount Operation"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo
    
    if ! wsl_is_vhd_attached "$umount_uuid"; then
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is not attached to WSL${NC}"
        [[ "$QUIET" == "false" ]] && echo "Nothing to do."
        [[ "$QUIET" == "false" ]] && echo "========================================"
        return 0
    fi
    
    [[ "$QUIET" == "false" ]] && echo -e "${BLUE}[i] VHD is attached to WSL${NC}"
    [[ "$QUIET" == "false" ]] && echo
    
    # First, unmount from filesystem if mounted
    if wsl_is_vhd_mounted "$umount_uuid"; then
        [[ "$QUIET" == "false" ]] && echo "Unmounting VHD from $umount_point..."
        if wsl_unmount_vhd "$umount_point"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD unmounted successfully${NC}"
        else
            echo -e "${RED}[✗] Failed to unmount VHD${NC}"
            echo "Tip: Make sure no processes are using the mount point"
            echo
            echo "Checking for processes using the mount point:"
            sudo lsof +D "$umount_point" 2>/dev/null || echo "  No processes found (or lsof not available)"
            echo
            echo "You can try to force unmount with: sudo umount -l $umount_point"
            exit 1
        fi
    else
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is not mounted to filesystem${NC}"
    fi
    
    # Then, detach from WSL
    [[ "$QUIET" == "false" ]] && echo "Detaching VHD from WSL..."
    if wsl_detach_vhd "$umount_path" "$umount_uuid"; then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD detached successfully${NC}"
    else
        echo -e "${RED}[✗] Failed to detach VHD from WSL${NC}"
        exit 1
    fi

    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$umount_uuid"
    
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  Unmount operation completed"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if ! wsl_is_vhd_attached "$umount_uuid"; then
            echo "$umount_path ($umount_uuid): detached"
        else
            echo "$umount_path ($umount_uuid): umount failed"
        fi
    fi
}

# Function to delete VHD
delete_vhd() {
    # Parse delete command arguments
    local delete_path=""
    local delete_uuid=""
    local force=false
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                delete_path="$2"
                shift 2
                ;;
            --uuid)
                delete_uuid="$2"
                shift 2
                ;;
            --force)
                force=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown delete option '$1'${NC}"
                echo
                show_usage
                ;;
        esac
    done
    
    # Validate that at least path is provided
    if [[ -z "$delete_path" ]]; then
        echo -e "${RED}Error: VHD path is required${NC}"
        echo "Use --path to specify the VHD file path"
        exit 1
    fi
    
    # Convert Windows path to WSL path to check if VHD exists
    local vhd_path_wsl=$(echo "$delete_path" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\\\|/|g')
    if [[ ! -e "$vhd_path_wsl" ]]; then
        echo -e "${RED}[✗] VHD file does not exist at $delete_path${NC}"
        echo "  (WSL path: $vhd_path_wsl)"
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Disk Deletion"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo
    
    # Try to discover UUID if not provided
    if [[ -z "$delete_uuid" ]]; then
        delete_uuid=$(wsl_find_uuid_by_path "$delete_path")
        if [[ -n "$delete_uuid" ]]; then
            [[ "$QUIET" == "false" ]] && echo "Discovered UUID from path: $delete_uuid"
            [[ "$QUIET" == "false" ]] && echo
        fi
    fi
    
    # Check if VHD is currently attached
    if [[ -n "$delete_uuid" ]] && wsl_is_vhd_attached "$delete_uuid"; then
        echo -e "${RED}[✗] VHD is currently attached to WSL${NC}"
        echo
        echo "The VHD must be unmounted and detached before deletion."
        echo "To unmount and detach, run:"
        echo "  $0 umount --path $delete_path"
        echo
        echo "Then try the delete command again."
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo "VHD file: $delete_path"
    [[ "$QUIET" == "false" ]] && echo "  (WSL path: $vhd_path_wsl)"
    [[ "$QUIET" == "false" ]] && echo
    
    # Confirmation prompt unless --force is used
    if [[ "$force" == "false" ]] && [[ "$QUIET" == "false" ]]; then
        echo -e "${YELLOW}[!] WARNING: This operation cannot be undone!${NC}"
        echo -n "Are you sure you want to delete this VHD? (yes/no): "
        read -r confirmation
        
        if [[ "$confirmation" != "yes" ]]; then
            echo "Deletion cancelled."
            exit 0
        fi
        echo
    fi
    
    # Delete the VHD file
    [[ "$QUIET" == "false" ]] && echo "Deleting VHD file..."
    if wsl_delete_vhd "$delete_path"; then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD deleted successfully${NC}"
        [[ "$QUIET" == "true" ]] && echo "$delete_path: deleted"
    else
        echo -e "${RED}[✗] Failed to delete VHD${NC}"
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  Deletion completed"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    
    return 0
}

# Function to create VHD
create_vhd() {
    # Parse create command arguments
    local create_path=""
    local create_size="1G"
    local create_name="disk"
    local create_mount_point=""
    local create_filesystem="ext4"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                create_path="$2"
                shift 2
                ;;
            --size)
                create_size="$2"
                shift 2
                ;;
            --name)
                create_name="$2"
                shift 2
                ;;
            --mount-point)
                create_mount_point="$2"
                shift 2
                ;;
            --filesystem)
                create_filesystem="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Error: Unknown create option '$1'${NC}"
                echo
                show_usage
                ;;
        esac
    done
    
    # Use defaults if not specified
    if [[ -z "$create_path" ]]; then
        create_path="${WSL_DISKS_DIR}${create_name}.vhdx"
    fi
    if [[ -z "$create_mount_point" ]]; then
        create_mount_point="/home/$USER/$create_name"
    fi
    
    # Validate required parameters
    if [[ -z "$create_path" ]]; then
        echo -e "${RED}Error: VHD path is required${NC}"
        echo "Use --path to specify the VHD file path"
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Disk Creation"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo
    
    # Check if VHD already exists
    local vhd_path_wsl=$(echo "$create_path" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\|/|g')
    if [[ -e "$vhd_path_wsl" ]]; then
        echo -e "${RED}[✗] VHD file already exists at $create_path${NC}"
        echo "Use 'mount' command to attach the existing VHD"
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo "Creating VHD disk..."
    [[ "$QUIET" == "false" ]] && echo "  Path: $create_path"
    [[ "$QUIET" == "false" ]] && echo "  Size: $create_size"
    [[ "$QUIET" == "false" ]] && echo "  Name: $create_name"
    [[ "$QUIET" == "false" ]] && echo "  Filesystem: $create_filesystem"
    [[ "$QUIET" == "false" ]] && echo "  Mount Point: $create_mount_point"
    [[ "$QUIET" == "false" ]] && echo
    
    # Create the VHD and capture the UUID
    local new_uuid
    if new_uuid=$(wsl_create_vhd "$create_path" "$create_size" "$create_filesystem" "$create_name" 2>&1); then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD created successfully${NC}"
        [[ "$QUIET" == "false" ]] && echo "  New UUID: $new_uuid"
        [[ "$QUIET" == "false" ]] && echo
        [[ "$QUIET" == "false" ]] && echo "The VHD is now attached to WSL but not mounted."
        [[ "$QUIET" == "false" ]] && echo "To mount it, run:"
        [[ "$QUIET" == "false" ]] && echo "  sudo mkdir -p $create_mount_point"
        [[ "$QUIET" == "false" ]] && echo "  sudo mount UUID=$new_uuid $create_mount_point"
        [[ "$QUIET" == "false" ]] && echo
        [[ "$QUIET" == "false" ]] && echo "========================================"
        [[ "$QUIET" == "false" ]] && echo "  Creation completed"
        [[ "$QUIET" == "false" ]] && echo "========================================"
        
        if [[ "$QUIET" == "true" ]]; then
            echo "$create_path: created with UUID=$new_uuid"
        fi
    else
        echo -e "${RED}[✗] Failed to create VHD${NC}"
        echo "$new_uuid"  # Print error message
        exit 1
    fi
}

# Main script logic
if [[ $# -eq 0 ]]; then
    show_usage
fi

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -q|--quiet)
            QUIET=true
            shift
            ;;
        -h|--help|help)
            show_usage
            ;;
        mount|umount|unmount|status|create|delete)
            COMMAND="$1"
            shift
            break
            ;;
        *)
            echo -e "${RED}Error: Unknown option or command '$1'${NC}"
            echo
            show_usage
            ;;
    esac
done

# Execute command
case "$COMMAND" in
    mount)
        mount_vhd "$@"  # Pass remaining arguments to mount_vhd
        ;;
    umount|unmount)
        umount_vhd "$@"  # Pass remaining arguments to umount_vhd
        ;;
    status)
        show_status "$@"  # Pass remaining arguments to show_status
        ;;
    create)
        create_vhd "$@"  # Pass remaining arguments to create_vhd
        ;;
    delete)
        delete_vhd "$@"  # Pass remaining arguments to delete_vhd
        ;;
    *)
        echo -e "${RED}Error: No command specified${NC}"
        echo
        show_usage
        ;;
esac
