#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration file
if [[ -f "$SCRIPT_DIR/config.sh" ]]; then
    source "$SCRIPT_DIR/config.sh"
fi

# Source helper functions (utils.sh first for validation functions)
source "$SCRIPT_DIR/libs/utils.sh"
source "$SCRIPT_DIR/libs/wsl_helpers.sh"

# Initialize runtime flags (can be overridden by command-line options)
QUIET="${QUIET:-false}"
DEBUG="${DEBUG:-false}"

# Export flags for child scripts
export QUIET
export DEBUG

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] COMMAND [COMMAND_OPTIONS]"
    echo
    echo "Options:"
    echo "  -q, --quiet  - Run in quiet mode (minimal output)"
    echo "  -d, --debug  - Run in debug mode (show all commands before execution)"
    echo
    echo "Commands:"
    echo "  attach [OPTIONS]         - Attach a VHD to WSL (without mounting to filesystem)"
    echo "  format [OPTIONS]         - Format an attached VHD with a filesystem"
    echo "  mount [OPTIONS]          - Attach and mount a formatted VHD disk"
    echo "  umount [OPTIONS]         - Unmount and detach the VHD disk"
    echo "  detach [OPTIONS]         - Detach a VHD disk (unmounts first if needed)"
    echo "  status [OPTIONS]         - Show current VHD disk status"
    echo "  create [OPTIONS]         - Create a new VHD disk"
    echo "  delete [OPTIONS]         - Delete a VHD disk file"
    echo "  resize [OPTIONS]         - Resize a VHD disk by creating new disk and migrating data"
    echo "  history [OPTIONS]        - Show detach history"
    echo
    echo "Attach Command Options:"
    echo "  --path PATH              - [mandatory] VHD file path (Windows format, e.g., C:/path/disk.vhdx)"
    local default_name="${DEFAULT_VHD_NAME:-disk}"
    echo "  --name NAME              - [optional] VHD name for WSL attachment [default: $default_name]"
    echo "  Note: Attaches VHD to WSL without mounting to filesystem."
    echo "        VHD will be accessible as a block device (/dev/sdX) after attachment."
    echo
    echo "Format Command Options:"
    echo "  --name NAME              - [optional] VHD device block name (e.g., sdd, sde)"
    echo "  --uuid UUID              - [optional] VHD UUID"
    local default_fs="${DEFAULT_FILESYSTEM_TYPE:-ext4}"
    echo "  --type TYPE              - [optional] Filesystem type (ext4, ext3, xfs, etc.) [default: $default_fs]"
    echo "  Note: Either --uuid or --name must be provided."
    echo "        VHD must be attached before formatting. Use 'attach' command first."
    echo "        If --uuid is provided for an already-formatted disk, confirmation will be required."
    echo
    echo "Mount Command Options:"
    echo "  --path PATH              - [mandatory] VHD file path (Windows format)"
    echo "  --mount-point PATH       - [mandatory] Mount point path"
    echo "  --name NAME              - [optional] VHD name for WSL attachment"
    echo "  Note: VHD must be formatted before mounting. Use 'format' command if needed."
    echo
    echo "Umount Command Options:"
    echo "  --path PATH              - [optional] VHD file path (Windows format, UUID will be discovered)"
    echo "  --uuid UUID              - [optional] VHD UUID (can be used instead of path or mount-point)"
    echo "  --mount-point PATH       - [optional] Mount point path (UUID will be discovered)"
    echo "  Note: Provide at least one option. UUID will be auto-discovered when possible."
    echo
    echo "Detach Command Options:"
    echo "  --uuid UUID              - [mandatory] VHD UUID to detach"
    echo "  --path PATH              - [optional] VHD file path (improves reliability)"
    echo "  Note: If VHD is mounted, it will be unmounted first."
    echo
    echo "Status Command Options:"
    echo "  --path PATH              - [optional] VHD file path (Windows format, UUID will be discovered)"
    echo "  --uuid UUID              - [optional] VHD UUID (can be used instead of path, name, or mount-point)"
    echo "  --name NAME              - [optional] VHD name (UUID will be discovered from tracking file)"
    echo "  --mount-point PATH       - [optional] Mount point path (UUID will be discovered)"
    echo "  --all                    - [optional] Show all attached VHDs"
    echo
    echo "Create Command Options:"
    echo "  --path PATH              - [mandatory] VHD file path (Windows format, e.g., C:/path/disk.vhdx)"
    local default_size="${DEFAULT_VHD_SIZE:-1G}"
    echo "  --size SIZE              - [optional] VHD size (e.g., 1G, 500M, 10G) [default: $default_size]"
    echo "  --force                  - [optional] Overwrite existing VHD (auto-unmounts if attached, prompts for confirmation)"
    echo "  Note: Creates VHD file only. Use 'attach' or 'mount' commands to attach and use the disk."
    echo
    echo "Delete Command Options:"
    echo "  --path PATH              - [mandatory] VHD file path (Windows format, UUID will be discovered)"
    echo "  --uuid UUID              - [optional] VHD UUID (can be used instead of path)"
    echo "  --force                  - [optional] Skip confirmation prompt"
    echo "  Note: VHD must be unmounted and detached before deletion."
    echo
    echo "Resize Command Options:"
    echo "  --mount-point PATH       - [mandatory] Target disk mount point"
    echo "  --size SIZE              - [mandatory] New disk size (e.g., 5G, 10G)"
    echo "  Note: Creates new disk, migrates data, and replaces original with backup."
    echo
    echo "History Command Options:"
    local default_limit="${DEFAULT_HISTORY_LIMIT:-10}"
    local max_limit="${MAX_HISTORY_LIMIT:-50}"
    echo "  --limit N                - [optional] Number of detach events to show [default: $default_limit, max: $max_limit]"
    echo "  --path PATH              - [optional] Show last detach event for specific VHD path"
    echo "  Note: Shows detach history with timestamps, UUIDs, and VHD names."
    echo
    echo "Examples:"
    echo "  $0 attach --path C:/VMs/disk.vhdx --name mydisk"
    echo "  $0 format --name sdd --type ext4"
    echo "  $0 format --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293 --type ext4"
    echo "  $0 mount --path C:/VMs/disk.vhdx --mount-point /mnt/data"
    echo "  $0 umount --path C:/VMs/disk.vhdx"
    echo "  $0 umount --mount-point /mnt/data"
    echo "  $0 umount --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293"
    echo "  $0 detach --uuid 72a3165c-f1be-4497-a1fb-2c55054ac472"
    echo "  $0 status --path C:/VMs/disk.vhdx"
    echo "  $0 status --name mydisk"
    echo "  $0 status --all"
    echo "  $0 create --path C:/VMs/disk.vhdx --size 5G"
    echo "  $0 delete --path C:/VMs/disk.vhdx"
    echo "  $0 delete --path C:/VMs/disk.vhdx --force"
    echo "  $0 resize --mount-point /mnt/data --size 10G"
    echo "  $0 history"
    echo "  $0 history --limit 20"
    echo "  $0 history --path C:/VMs/disk.vhdx"
    echo "  $0 -q status --all"
    echo
    exit 0
}

# Function to show status
show_status() {
    # Parse status command arguments
    local status_path=""
    local status_uuid=""
    local status_name=""
    local status_mount_point=""
    local show_all=false
    
    # If no arguments, show help
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 status [OPTIONS]"
        echo
        echo "Options:"
        echo "  --path PATH         Show status for specific VHD path (UUID auto-discovered)"
        echo "  --uuid UUID         Show status for specific UUID"
        echo "  --name NAME         Show status for specific VHD name (UUID auto-discovered)"
        echo "  --mount-point PATH  Show status for specific mount point (UUID auto-discovered)"
        echo "  --all               Show all attached VHDs"
        echo
        echo "Examples:"
        echo "  $0 status --all"
        echo "  $0 status --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293"
        echo "  $0 status --path C:/VMs/disk.vhdx"
        echo "  $0 status --name mydisk"
        echo "  $0 status --mount-point /mnt/data"
        return 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --path requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_windows_path "$2"; then
                    echo -e "${RED}Error: Invalid path format: $2${NC}" >&2
                    echo "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)" >&2
                    return 1
                fi
                status_path="$2"
                shift 2
                ;;
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --uuid requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_uuid "$2"; then
                    echo -e "${RED}Error: Invalid UUID format: $2${NC}" >&2
                    echo "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" >&2
                    return 1
                fi
                status_uuid="$2"
                shift 2
                ;;
            --name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --name requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_vhd_name "$2"; then
                    echo -e "${RED}Error: Invalid VHD name format: $2${NC}" >&2
                    echo "VHD name must contain only alphanumeric characters, hyphens, and underscores" >&2
                    return 1
                fi
                status_name="$2"
                shift 2
                ;;
            --mount-point)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --mount-point requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_mount_point "$2"; then
                    echo -e "${RED}Error: Invalid mount point format: $2${NC}" >&2
                    echo "Mount point must be an absolute path (e.g., /mnt/data)" >&2
                    return 1
                fi
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
        # If name is provided, lookup UUID from tracking file
        if [[ -n "$status_name" ]]; then
            status_uuid=$(lookup_vhd_uuid_by_name "$status_name")
            
            if [[ -z "$status_uuid" ]]; then
                echo -e "${RED}[✗] VHD name not found in tracking file${NC}"
                echo
                echo "VHD with name '$status_name' is not tracked."
                echo
                echo "Suggestions:"
                echo "  1. Check the name is correct (case-sensitive)"
                echo "  2. VHD might be attached with a different name"
                echo "  3. See all attached VHDs: $0 status --all"
                
                [[ "$QUIET" == "true" ]] && echo "not found"
                return 1
            fi
            
            # Verify the UUID is actually attached
            if ! wsl_is_vhd_attached "$status_uuid"; then
                echo -e "${YELLOW}[!] VHD found in tracking but not currently attached${NC}"
                echo
                echo "VHD with name '$status_name' (UUID: $status_uuid) is not attached."
                echo "The tracking file may be stale."
                
                [[ "$QUIET" == "true" ]] && echo "not attached"
                return 1
            fi
            
            [[ "$QUIET" == "false" ]] && echo "Discovered UUID from name '$status_name': $status_uuid"
            [[ "$QUIET" == "false" ]] && echo
        # If path is provided, check if VHD file exists first
        elif [[ -n "$status_path" ]]; then
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
            
            # File exists, try to find UUID by path with multi-VHD safety
            local discovery_result
            status_uuid=$(wsl_find_uuid_by_path "$status_path" 2>&1)
            discovery_result=$?
            
            if [[ $discovery_result -eq 2 ]]; then
                # Multiple VHDs detected
                echo -e "${YELLOW}[!] Multiple VHDs are attached${NC}"
                echo "Cannot determine UUID from path alone."
                echo "Run '$0 status --all' to see all attached VHDs."
                [[ "$QUIET" == "true" ]] && echo "ambiguous: multiple VHDs"
                return 1
            elif [[ -n "$status_uuid" ]]; then
                [[ "$QUIET" == "false" ]] && echo "Found VHD UUID: $status_uuid"
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
        [[ "$QUIET" == "false" ]] && echo "Note: VHD paths cannot be determined from UUID alone."
        [[ "$QUIET" == "false" ]] && echo "      Use 'status --path <path>' to verify a specific VHD."
        [[ "$QUIET" == "false" ]] && echo
        
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
    if [[ -n "$status_path" ]]; then
        [[ "$QUIET" == "false" ]] && echo "  Path: $status_path"
    else
        [[ "$QUIET" == "false" ]] && echo "  Path: Unknown (use --path to query by path)"
    fi
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
    local mount_path=""
    local mount_point=""
    local default_name="${DEFAULT_VHD_NAME:-disk}"
    local mount_name="$default_name"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --path requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_windows_path "$2"; then
                    echo -e "${RED}Error: Invalid path format: $2${NC}" >&2
                    echo "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)" >&2
                    exit 1
                fi
                mount_path="$2"
                shift 2
                ;;
            --mount-point)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --mount-point requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_mount_point "$2"; then
                    echo -e "${RED}Error: Invalid mount point format: $2${NC}" >&2
                    echo "Mount point must be an absolute path (e.g., /mnt/data)" >&2
                    exit 1
                fi
                mount_point="$2"
                shift 2
                ;;
            --name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --name requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_vhd_name "$2"; then
                    echo -e "${RED}Error: Invalid VHD name format: $2${NC}" >&2
                    echo "VHD name must contain only alphanumeric characters, hyphens, and underscores" >&2
                    exit 1
                fi
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
    
    # Validate required parameters
    if [[ -z "$mount_path" ]]; then
        echo -e "${RED}Error: --path parameter is required${NC}"
        echo "Usage: $0 mount --path PATH --mount-point MOUNT_POINT [--name NAME]"
        exit 1
    fi
    
    if [[ -z "$mount_point" ]]; then
        echo -e "${RED}Error: --mount-point parameter is required${NC}"
        echo "Usage: $0 mount --path PATH --mount-point MOUNT_POINT [--name NAME]"
        exit 1
    fi
    
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
        
        # If no UUID found, the VHD is unformatted
        if [[ -z "$mount_uuid" ]]; then
            if [[ -z "$new_dev" ]]; then
                echo -e "${RED}[✗] Failed to detect device of attached VHD${NC}"
                exit 1
            fi
            
            echo -e "${RED}[✗] VHD has no filesystem${NC}"
            echo
            echo "The VHD is attached but not formatted."
            echo "  Device: /dev/$new_dev"
            echo
            echo "To format the VHD, run:"
            echo "  $0 format --name $new_dev --type ext4"
            echo
            echo "Or use a different filesystem type (ext3, xfs, etc.):"
            echo "  $0 format --name $new_dev --type xfs"
            exit 1
        fi
        
        [[ "$QUIET" == "false" ]] && echo "  Detected UUID: $mount_uuid"
        [[ "$QUIET" == "false" ]] && [[ -n "$new_dev" ]] && echo "  Detected Device: /dev/$new_dev"
    else
        # VHD might already be attached, try to find it safely
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD appears to be already attached, searching for UUID...${NC}"
        
        # Use safe UUID discovery with multi-VHD detection
        local discovery_result
        mount_uuid=$(wsl_find_uuid_by_path "$mount_path" 2>&1)
        discovery_result=$?
        
        if [[ $discovery_result -eq 2 ]]; then
            # Multiple VHDs detected - cannot safely determine which one
            echo -e "${RED}[✗] Cannot determine UUID: Multiple VHDs are attached${NC}"
            echo
            echo "Use one of these options:"
            echo "  1. View all attached VHDs: $0 status --all"
            echo "  2. Detach other VHDs first, then retry"
            echo "  3. Use explicit UUID if known: $0 mount --path $mount_path --mount-point $mount_point (then provide UUID)"
            exit 1
        elif [[ -z "$mount_uuid" ]]; then
            echo -e "${RED}[✗] Could not detect UUID of VHD${NC}"
            echo "The VHD file exists but is not attached to WSL."
            echo "Try running: $0 status --all"
            exit 1
        else
            [[ "$QUIET" == "false" ]] && echo "  Found UUID: $mount_uuid"
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
            if ! create_mount_point "$mount_point"; then
                echo -e "${RED}[✗] Failed to create mount point${NC}"
                exit 1
            fi
        fi
        
        [[ "$QUIET" == "false" ]] && echo "Mounting VHD to $mount_point..."
        if wsl_mount_vhd "$mount_uuid" "$mount_point"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD mounted successfully${NC}"
            
            # Update mount point in tracking file
            update_vhd_mount_points "$mount_path" "$mount_point"
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
    local umount_path=""
    local umount_uuid=""
    local umount_point=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --path requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_windows_path "$2"; then
                    echo -e "${RED}Error: Invalid path format: $2${NC}" >&2
                    echo "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)" >&2
                    return 1
                fi
                umount_path="$2"
                shift 2
                ;;
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --uuid requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_uuid "$2"; then
                    echo -e "${RED}Error: Invalid UUID format: $2${NC}" >&2
                    echo "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" >&2
                    return 1
                fi
                umount_uuid="$2"
                shift 2
                ;;
            --mount-point)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --mount-point requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_mount_point "$2"; then
                    echo -e "${RED}Error: Invalid mount point format: $2${NC}" >&2
                    echo "Mount point must be an absolute path (e.g., /mnt/data)" >&2
                    return 1
                fi
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
            # Try to find UUID by path with multi-VHD safety
            local discovery_result
            umount_uuid=$(wsl_find_uuid_by_path "$umount_path" 2>&1)
            discovery_result=$?
            
            if [[ $discovery_result -eq 2 ]]; then
                # Multiple VHDs detected
                echo -e "${RED}[✗] Cannot determine UUID: Multiple VHDs are attached${NC}"
                echo
                echo "Please specify --uuid explicitly or run: $0 status --all"
                [[ "$QUIET" == "true" ]] && echo "ambiguous: multiple VHDs"
                return 1
            elif [[ -n "$umount_uuid" ]]; then
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
        # Discover mount point if not provided
        if [[ -z "$umount_point" ]]; then
            umount_point=$(wsl_get_vhd_mount_point "$umount_uuid")
        fi
        
        [[ "$QUIET" == "false" ]] && echo "Unmounting VHD from $umount_point..."
        if wsl_umount_vhd "$umount_point"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD unmounted successfully${NC}"
            
            # Clear mount point in tracking file if we have the path
            if [[ -n "$umount_path" ]]; then
                update_vhd_mount_points "$umount_path" ""
            fi
        else
            exit 1
        fi
    else
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is not mounted to filesystem${NC}"
    fi
    
    # Then, detach from WSL (only if path was provided)
    if [[ -n "$umount_path" ]]; then
        [[ "$QUIET" == "false" ]] && echo "Detaching VHD from WSL..."
        # Get VHD name from tracking file for history
        local umount_name=""
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            local normalized_path=$(normalize_vhd_path "$umount_path")
            umount_name=$(jq -r --arg path "$normalized_path" '.mappings[$path].name // empty' "$DISK_TRACKING_FILE" 2>/dev/null)
        fi
        if wsl_detach_vhd "$umount_path" "$umount_uuid" "$umount_name"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD detached successfully${NC}"
        else
            echo -e "${RED}[✗] Failed to detach VHD from WSL${NC}"
            exit 1
        fi
    else
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD was not detached from WSL${NC}"
        [[ "$QUIET" == "false" ]] && echo "The VHD path is required to detach from WSL."
        [[ "$QUIET" == "false" ]] && echo
        [[ "$QUIET" == "false" ]] && echo "To fully detach the VHD, run:"
        [[ "$QUIET" == "false" ]] && echo "  $0 detach --path <VHD_PATH>"
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
        elif [[ -z "$umount_path" ]]; then
            echo "($umount_uuid): unmounted,attached"
        else
            echo "$umount_path ($umount_uuid): umount failed"
        fi
    fi
}

# Function to detach VHD by UUID
detach_vhd() {
    # Parse detach command arguments
    local detach_uuid=""
    local detach_path=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --uuid requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_uuid "$2"; then
                    echo -e "${RED}Error: Invalid UUID format: $2${NC}" >&2
                    echo "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" >&2
                    exit 1
                fi
                detach_uuid="$2"
                shift 2
                ;;
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --path requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_windows_path "$2"; then
                    echo -e "${RED}Error: Invalid path format: $2${NC}" >&2
                    echo "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)" >&2
                    exit 1
                fi
                detach_path="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Error: Unknown detach option '$1'${NC}"
                echo
                show_usage
                ;;
        esac
    done
    
    # Validate that UUID is provided
    if [[ -z "$detach_uuid" ]]; then
        echo -e "${RED}Error: --uuid is required${NC}"
        echo "Use --uuid to specify the VHD UUID to detach"
        echo "To find UUIDs, run: $0 status --all"
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Disk Detach Operation"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo
    
    # Check if VHD is attached
    if ! wsl_is_vhd_attached "$detach_uuid"; then
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is not attached to WSL${NC}"
        [[ "$QUIET" == "false" ]] && echo "Nothing to do."
        [[ "$QUIET" == "true" ]] && echo "$detach_uuid: not attached"
        [[ "$QUIET" == "false" ]] && echo "========================================"
        return 0
    fi
    
    [[ "$QUIET" == "false" ]] && echo -e "${BLUE}[i] VHD is attached to WSL${NC}"
    [[ "$QUIET" == "false" ]] && echo "  UUID: $detach_uuid"
    [[ "$QUIET" == "false" ]] && echo
    
    # Path is optional for detach - WSL can detach by UUID alone
    # If path is provided, it will be used; otherwise detach will work without it
    
    # Show current VHD info
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$detach_uuid"
    [[ "$QUIET" == "false" ]] && echo
    
    # Check if mounted and unmount first
    if wsl_is_vhd_mounted "$detach_uuid"; then
        local mount_point=$(wsl_get_vhd_mount_point "$detach_uuid")
        [[ "$QUIET" == "false" ]] && echo "VHD is mounted at: $mount_point"
        [[ "$QUIET" == "false" ]] && echo "Unmounting VHD first..."
        
        if wsl_umount_vhd "$mount_point"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD unmounted successfully${NC}"
            
            # Clear mount point in tracking file if we have the path
            if [[ -n "$detach_path" ]]; then
                update_vhd_mount_points "$detach_path" ""
            fi
        else
            exit 1
        fi
        [[ "$QUIET" == "false" ]] && echo
    else
        [[ "$QUIET" == "false" ]] && echo -e "${BLUE}[i] VHD is not mounted to filesystem${NC}"
        [[ "$QUIET" == "false" ]] && echo
    fi
    
    # Detach from WSL
    [[ "$QUIET" == "false" ]] && echo "Detaching VHD from WSL..."
    
    if [[ -n "$detach_path" ]]; then
        # Get VHD name from tracking file for history
        local detach_name=""
        if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
            local normalized_path=$(normalize_vhd_path "$detach_path")
            detach_name=$(jq -r --arg path "$normalized_path" '.mappings[$path].name // empty' "$DISK_TRACKING_FILE" 2>/dev/null)
        fi
        
        # Use path if we have it, pass UUID and name for history tracking
        if wsl_detach_vhd "$detach_path" "$detach_uuid" "$detach_name"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD detached successfully${NC}"
        else
            echo -e "${RED}[✗] Failed to detach VHD from WSL${NC}"
            exit 1
        fi
    else
        # If we couldn't find the path, report error with helpful message
        echo -e "${RED}[✗] Could not determine VHD path${NC}"
        echo
        echo "The VHD path could not be found automatically."
        echo "Please provide the path explicitly:"
        echo "  $0 detach --uuid $detach_uuid --path <vhd_path>"
        echo
        echo "Or use the umount command if you know the path or mount point:"
        echo "  $0 umount --path <vhd_path>"
        echo "  $0 umount --mount-point <mount_point>"
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  Detach operation completed"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if ! wsl_is_vhd_attached "$detach_uuid"; then
            echo "$detach_uuid: detached"
        else
            echo "$detach_uuid: detach failed"
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
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --path requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_windows_path "$2"; then
                    echo -e "${RED}Error: Invalid path format: $2${NC}" >&2
                    echo "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)" >&2
                    exit 1
                fi
                delete_path="$2"
                shift 2
                ;;
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --uuid requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_uuid "$2"; then
                    echo -e "${RED}Error: Invalid UUID format: $2${NC}" >&2
                    echo "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" >&2
                    exit 1
                fi
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
        local discovery_result
        delete_uuid=$(wsl_find_uuid_by_path "$delete_path" 2>&1)
        discovery_result=$?
        
        if [[ $discovery_result -eq 2 ]]; then
            # Multiple VHDs detected - not a blocker for delete, just can't verify attachment
            [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] Multiple VHDs attached - cannot verify if this VHD is attached${NC}"
            [[ "$QUIET" == "false" ]] && echo "Proceeding with caution..."
            [[ "$QUIET" == "false" ]] && echo
            delete_uuid=""  # Clear to skip attachment check
        elif [[ -n "$delete_uuid" ]]; then
            [[ "$QUIET" == "false" ]] && echo "Discovered UUID from path: $delete_uuid"
            [[ "$QUIET" == "false" ]] && echo
        fi
    fi
    
    # Check if VHD is currently attached
    if [[ -n "$delete_uuid" ]] && wsl_is_vhd_attached "$delete_uuid"; then
        # Try to automatically detach before failing
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is currently attached to WSL${NC}"
        [[ "$QUIET" == "false" ]] && echo "Attempting to detach automatically..."
        
        # Try umount first (handles both unmount and detach)
        if [[ -n "$delete_path" ]]; then
            if bash "$0" -q umount --path "$delete_path" >/dev/null 2>&1; then
                [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD detached successfully${NC}"
                # Wait a moment for detachment to complete
                sleep 1
            else
                # Umount failed, try direct wsl.exe --unmount as fallback
                if wsl.exe --unmount "$delete_path" >/dev/null 2>&1; then
                    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD detached successfully${NC}"
                    sleep 1
                else
                    echo -e "${RED}[✗] VHD is currently attached to WSL and could not be detached${NC}"
                    echo
                    echo "The VHD must be unmounted and detached before deletion."
                    echo "To unmount and detach, run:"
                    echo "  $0 umount --path $delete_path"
                    echo
                    echo "Then try the delete command again."
                    exit 1
                fi
            fi
        else
            echo -e "${RED}[✗] VHD is currently attached to WSL${NC}"
            echo
            echo "The VHD must be unmounted and detached before deletion."
            echo "To unmount and detach, run:"
            echo "  $0 umount --uuid $delete_uuid"
            echo
            echo "Then try the delete command again."
            exit 1
        fi
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
        
        # Remove mapping from tracking file
        remove_vhd_mapping "$delete_path"
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
    local default_size="${DEFAULT_VHD_SIZE:-1G}"
    local create_size="$default_size"
    local force="false"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --path requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_windows_path "$2"; then
                    echo -e "${RED}Error: Invalid path format: $2${NC}" >&2
                    echo "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)" >&2
                    exit 1
                fi
                create_path="$2"
                shift 2
                ;;
            --size)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --size requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_size_string "$2"; then
                    echo -e "${RED}Error: Invalid size format: $2${NC}" >&2
                    echo "Size must be in format: number[K|M|G|T] (e.g., 5G, 500M)" >&2
                    exit 1
                fi
                create_size="$2"
                shift 2
                ;;
            --force)
                force="true"
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown create option '$1'${NC}"
                echo
                show_usage
                ;;
        esac
    done
    
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
        if [[ "$force" == "false" ]]; then
            echo -e "${RED}[✗] VHD file already exists at $create_path${NC}"
            echo "Use 'mount' command to attach the existing VHD, or use --force to overwrite"
            exit 1
        else
            # Force mode: prompt for confirmation before deleting
            [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD file already exists at $create_path${NC}"
            [[ "$QUIET" == "false" ]] && echo
            
            # Check if VHD is currently attached (with multi-VHD safety)
            local existing_uuid
            local discovery_result
            existing_uuid=$(wsl_find_uuid_by_path "$create_path" 2>&1)
            discovery_result=$?
            
            # Only check attachment if we have a UUID (skip if multiple VHDs or not found)
            if [[ $discovery_result -eq 0 && -n "$existing_uuid" ]] && wsl_is_vhd_attached "$existing_uuid"; then
                [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is currently attached to WSL${NC}"
                [[ "$QUIET" == "false" ]] && echo
                
                # Ask for permission to unmount in non-quiet mode
                if [[ "$QUIET" == "false" ]]; then
                    echo -e "${YELLOW}[!] The VHD must be unmounted before overwriting.${NC}"
                    echo -n "Do you want to unmount it now? (yes/no): "
                    read -r unmount_confirmation
                    
                    if [[ "$unmount_confirmation" != "yes" ]]; then
                        echo "Operation cancelled."
                        echo
                        echo "To unmount manually, run:"
                        echo "  $0 umount --path $create_path"
                        exit 0
                    fi
                    echo
                fi
                
                # Perform unmount operation
                [[ "$QUIET" == "false" ]] && echo "Unmounting VHD..."
                
                # Check if mounted and unmount from filesystem first
                if wsl_is_vhd_mounted "$existing_uuid"; then
                    local existing_mount_point=$(wsl_get_vhd_mount_point "$existing_uuid")
                    if [[ -n "$existing_mount_point" ]]; then
                        if wsl_umount_vhd "$existing_mount_point"; then
                            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD unmounted from filesystem${NC}"
                        else
                            echo -e "${RED}[✗] Failed to unmount VHD from filesystem${NC}"
                            echo "Checking for processes using the mount point:"
                            sudo lsof +D "$existing_mount_point" 2>/dev/null || echo "  No processes found"
                            exit 1
                        fi
                    fi
                fi
                
                # Detach from WSL
                # Get VHD name from tracking file for history
                local existing_name=""
                if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
                    local normalized_path=$(normalize_vhd_path "$create_path")
                    existing_name=$(jq -r --arg path "$normalized_path" '.mappings[$path].name // empty' "$DISK_TRACKING_FILE" 2>/dev/null)
                fi
                if wsl_detach_vhd "$create_path" "$existing_uuid" "$existing_name"; then
                    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD detached from WSL${NC}"
                    [[ "$QUIET" == "false" ]] && echo
                else
                    echo -e "${RED}[✗] Failed to detach VHD from WSL${NC}"
                    exit 1
                fi
                
                # Small delay to ensure detachment is complete
                sleep 1
            fi
            
            # Confirmation prompt in non-quiet mode
            if [[ "$QUIET" == "false" ]]; then
                echo -e "${YELLOW}[!] WARNING: This will permanently delete the existing VHD file!${NC}"
                echo -n "Are you sure you want to overwrite $create_path? (yes/no): "
                read -r confirmation
                
                if [[ "$confirmation" != "yes" ]]; then
                    echo "Operation cancelled."
                    exit 0
                fi
                echo
            fi
            
            # Delete the existing VHD
            [[ "$QUIET" == "false" ]] && echo "Deleting existing VHD file..."
            if [[ "$DEBUG" == "true" ]]; then
                echo -e "${BLUE}[DEBUG]${NC} rm -f '$vhd_path_wsl'" >&2
            fi
            if rm -f "$vhd_path_wsl"; then
                [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] Existing VHD deleted${NC}"
                [[ "$QUIET" == "false" ]] && echo
            else
                echo -e "${RED}[✗] Failed to delete existing VHD${NC}"
                exit 1
            fi
        fi
    fi
    
    [[ "$QUIET" == "false" ]] && echo "Creating VHD disk..."
    [[ "$QUIET" == "false" ]] && echo "  Path: $create_path"
    [[ "$QUIET" == "false" ]] && echo "  Size: $create_size"
    [[ "$QUIET" == "false" ]] && echo
    
    # Ensure qemu-img is installed
    if ! command -v qemu-img &> /dev/null; then
        echo -e "${RED}[✗] qemu-img is not installed${NC}"
        echo "Please install it first:"
        echo "  Arch/Manjaro: sudo pacman -Sy qemu-img"
        echo "  Ubuntu/Debian: sudo apt install qemu-utils"
        echo "  Fedora: sudo dnf install qemu-img"
        exit 1
    fi
    
    # Create parent directory if it doesn't exist
    local vhd_dir=$(dirname "$vhd_path_wsl")
    if [[ ! -d "$vhd_dir" ]]; then
        [[ "$QUIET" == "false" ]] && echo "Creating directory: $vhd_dir"
        if ! debug_cmd mkdir -p "$vhd_dir" 2>/dev/null; then
            echo -e "${RED}[✗] Failed to create directory $vhd_dir${NC}"
            exit 1
        fi
    fi
    
    # Create the VHD file
    if ! debug_cmd qemu-img create -f vhdx "$vhd_path_wsl" "$create_size" >/dev/null 2>&1; then
        echo -e "${RED}[✗] Failed to create VHD file${NC}"
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD file created successfully${NC}"
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  Creation completed"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "The VHD file has been created but is not attached or formatted."
    [[ "$QUIET" == "false" ]] && echo "To use it, you need to:"
    [[ "$QUIET" == "false" ]] && echo "  1. Attach the VHD:"
    [[ "$QUIET" == "false" ]] && echo "     $0 attach --path $create_path --name <name>"
    [[ "$QUIET" == "false" ]] && echo "  2. Format the VHD:"
    [[ "$QUIET" == "false" ]] && echo "     $0 format --name <device_name> --type ext4"
    [[ "$QUIET" == "false" ]] && echo "  3. Mount the formatted VHD:"
    [[ "$QUIET" == "false" ]] && echo "     $0 mount --path $create_path --mount-point <mount_point>"
    [[ "$QUIET" == "false" ]] && echo
    
    if [[ "$QUIET" == "true" ]]; then
        echo "$create_path: created"
    fi
}

# Function to resize VHD
resize_vhd() {
    # Parse resize command arguments
    local target_mount_point=""
    local new_size=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mount-point)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --mount-point requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_mount_point "$2"; then
                    echo -e "${RED}Error: Invalid mount point format: $2${NC}" >&2
                    echo "Mount point must be an absolute path (e.g., /mnt/data)" >&2
                    exit 1
                fi
                target_mount_point="$2"
                shift 2
                ;;
            --size)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --size requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_size_string "$2"; then
                    echo -e "${RED}Error: Invalid size format: $2${NC}" >&2
                    echo "Size must be in format: number[K|M|G|T] (e.g., 5G, 500M)" >&2
                    exit 1
                fi
                new_size="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Error: Unknown resize option '$1'${NC}"
                echo
                show_usage
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$target_mount_point" ]]; then
        echo -e "${RED}Error: --mount-point is required${NC}"
        echo "Specify the mount point of the target disk to resize"
        exit 1
    fi
    
    if [[ -z "$new_size" ]]; then
        echo -e "${RED}Error: --size is required${NC}"
        echo "Specify the new size for the disk (e.g., 5G, 10G)"
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Disk Resize Operation"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo
    
    # Check if target mount point exists and is mounted
    if [[ ! -d "$target_mount_point" ]]; then
        echo -e "${RED}[✗] Target mount point does not exist: $target_mount_point${NC}"
        exit 1
    fi
    
    # Find UUID of target disk
    local target_uuid=$(wsl_find_uuid_by_mountpoint "$target_mount_point")
    if [[ -z "$target_uuid" ]]; then
        echo -e "${RED}[✗] No VHD mounted at $target_mount_point${NC}"
        echo "Please ensure the target disk is mounted first"
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] Found target disk${NC}"
    [[ "$QUIET" == "false" ]] && echo "  UUID: $target_uuid"
    [[ "$QUIET" == "false" ]] && echo "  Mount Point: $target_mount_point"
    [[ "$QUIET" == "false" ]] && echo
    
    # Get target disk path by finding device and checking lsblk
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} lsblk -f -J | jq -r --arg UUID '$target_uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'" >&2
    fi
    local target_device=$(lsblk -f -J | jq -r --arg UUID "$target_uuid" '.blockdevices[] | select(.uuid == $UUID) | .name' 2>/dev/null)
    
    if [[ -z "$target_device" ]]; then
        echo -e "${RED}[✗] Could not find device for UUID $target_uuid${NC}"
        exit 1
    fi
    
    # Calculate total size of all files in target disk
    [[ "$QUIET" == "false" ]] && echo "Calculating size of files in target disk..."
    local target_size_bytes=$(get_directory_size_bytes "$target_mount_point")
    local target_size_human=$(bytes_to_human "$target_size_bytes")
    
    [[ "$QUIET" == "false" ]] && echo "  Total size of files: $target_size_human ($target_size_bytes bytes)"
    [[ "$QUIET" == "false" ]] && echo
    
    # Convert new_size to bytes
    local new_size_bytes=$(convert_size_to_bytes "$new_size")
    local required_size_bytes=$((target_size_bytes * 130 / 100))  # Add 30%
    local required_size_human=$(bytes_to_human "$required_size_bytes")
    
    # Determine actual size to use
    local actual_size_bytes=$new_size_bytes
    local actual_size_str="$new_size"
    
    if [[ $new_size_bytes -lt $required_size_bytes ]]; then
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] Requested size ($new_size) is smaller than required${NC}"
        [[ "$QUIET" == "false" ]] && echo "  Minimum required: $required_size_human (files + 30%)"
        [[ "$QUIET" == "false" ]] && echo "  Using minimum required size instead"
        actual_size_bytes=$required_size_bytes
        actual_size_str=$required_size_human
        [[ "$QUIET" == "false" ]] && echo
    fi
    
    # Count files in target disk
    [[ "$QUIET" == "false" ]] && echo "Counting files in target disk..."
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} find '$target_mount_point' -type f | wc -l" >&2
    fi
    local target_file_count=$(find "$target_mount_point" -type f 2>/dev/null | wc -l)
    [[ "$QUIET" == "false" ]] && echo "  File count: $target_file_count"
    [[ "$QUIET" == "false" ]] && echo
    
    # We need to find the VHD path by looking it up from the tracking file using UUID
    local target_vhd_path=""
    local target_vhd_name=""
    
    # Look up VHD path from tracking file using UUID
    if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
        if [[ "$DEBUG" == "true" ]]; then
            echo -e "${BLUE}[DEBUG]${NC} jq -r --arg uuid '$target_uuid' '.mappings[] | select(.uuid == \$uuid) | path(.) | .[-1]' $DISK_TRACKING_FILE" >&2
        fi
        # Find the path (key) that has this UUID
        local normalized_path=$(jq -r --arg uuid "$target_uuid" '.mappings | to_entries[] | select(.value.uuid == $uuid) | .key' "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
        
        if [[ -n "$normalized_path" && "$normalized_path" != "null" ]]; then
            # Convert normalized path back to Windows format (uppercase drive letter)
            # Normalized format is lowercase: c:/vms/disk.vhdx
            # Windows format should be: C:/VMs/disk.vhdx (but we'll use as-is since tracking uses lowercase)
            target_vhd_path="$normalized_path"
            # Extract name from tracking file if available
            target_vhd_name=$(jq -r --arg uuid "$target_uuid" '.mappings | to_entries[] | select(.value.uuid == $uuid) | .value.name // empty' "$DISK_TRACKING_FILE" 2>/dev/null | head -n 1)
        fi
    fi
    
    # If path lookup failed, try to infer from mount point name as fallback
    if [[ -z "$target_vhd_path" ]]; then
        target_vhd_name=$(basename "$target_mount_point")
        echo -e "${RED}[✗] Cannot determine VHD path from tracking file${NC}"
        echo "The VHD path is required for resize operation."
        echo "Please ensure the VHD was attached/mounted using disk_management.sh so it's tracked."
        echo "Alternatively, you can manually specify the path by modifying the resize command."
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo "Target VHD path: $target_vhd_path"
    if [[ -n "$target_vhd_name" ]]; then
        [[ "$QUIET" == "false" ]] && echo "Target VHD name: $target_vhd_name"
    fi
    [[ "$QUIET" == "false" ]] && echo
    
    # Create new VHD with temporary name
    local target_vhd_dir=$(dirname "${target_vhd_path}")
    local target_vhd_basename=$(basename "$target_vhd_path" .vhdx)
    target_vhd_basename=$(basename "$target_vhd_basename" .vhd)
    local new_vhd_path="${target_vhd_dir}/${target_vhd_basename}_temp.vhdx"
    local temp_mount_point="${target_mount_point}_temp"
    
    [[ "$QUIET" == "false" ]] && echo -e "${BLUE}[i] Creating new VHD${NC}"
    [[ "$QUIET" == "false" ]] && echo "  Path: $new_vhd_path"
    [[ "$QUIET" == "false" ]] && echo "  Size: $actual_size_str"
    [[ "$QUIET" == "false" ]] && echo "  Mount Point: $temp_mount_point"
    [[ "$QUIET" == "false" ]] && echo
    
    # Create new VHD
    local new_uuid
    if new_uuid=$(wsl_create_vhd "$new_vhd_path" "$actual_size_str" "ext4" "${target_vhd_basename}_temp" 2>&1); then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] New VHD created${NC}"
        [[ "$QUIET" == "false" ]] && echo "  New UUID: $new_uuid"
    else
        echo -e "${RED}[✗] Failed to create new VHD${NC}"
        echo "$new_uuid"  # Print error message
        exit 1
    fi
    [[ "$QUIET" == "false" ]] && echo
    
    # Mount the new VHD
    [[ "$QUIET" == "false" ]] && echo "Mounting new VHD at $temp_mount_point..."
    if [[ ! -d "$temp_mount_point" ]]; then
        if ! create_mount_point "$temp_mount_point"; then
            echo -e "${RED}[✗] Failed to create temporary mount point${NC}"
            wsl_detach_vhd "$new_vhd_path" "$new_uuid" ""
            wsl_delete_vhd "$new_vhd_path"
            exit 1
        fi
    fi
    
    if wsl_mount_vhd "$new_uuid" "$temp_mount_point"; then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] New VHD mounted${NC}"
    else
        echo -e "${RED}[✗] Failed to mount new VHD${NC}"
        # Cleanup
        wsl_detach_vhd "$new_vhd_path" "$new_uuid" ""
        wsl_delete_vhd "$new_vhd_path"
        exit 1
    fi
    [[ "$QUIET" == "false" ]] && echo
    
    # Copy all files from target disk to new disk
    [[ "$QUIET" == "false" ]] && echo "Copying files from target disk to new disk..."
    [[ "$QUIET" == "false" ]] && echo "  This may take a while depending on data size..."
    
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} sudo rsync -a '$target_mount_point/' '$temp_mount_point/'" >&2
    fi
    
    if sudo rsync -a "$target_mount_point/" "$temp_mount_point/" 2>&1; then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] Files copied successfully${NC}"
    else
        echo -e "${RED}[✗] Failed to copy files${NC}"
        # Cleanup
        wsl_umount_vhd "$temp_mount_point"
        wsl_detach_vhd "$new_vhd_path" "$new_uuid" ""
        wsl_delete_vhd "$new_vhd_path"
        exit 1
    fi
    [[ "$QUIET" == "false" ]] && echo
    
    # Verify file count and size
    [[ "$QUIET" == "false" ]] && echo "Verifying new disk..."
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} find '$temp_mount_point' -type f | wc -l" >&2
    fi
    local new_file_count=$(find "$temp_mount_point" -type f 2>/dev/null | wc -l)
    local new_size_bytes=$(get_directory_size_bytes "$temp_mount_point")
    local new_size_human=$(bytes_to_human "$new_size_bytes")
    
    [[ "$QUIET" == "false" ]] && echo "  Original file count: $target_file_count"
    [[ "$QUIET" == "false" ]] && echo "  New file count: $new_file_count"
    [[ "$QUIET" == "false" ]] && echo "  Original size: $target_size_human"
    [[ "$QUIET" == "false" ]] && echo "  New size: $new_size_human"
    
    if [[ $new_file_count -ne $target_file_count ]]; then
        echo -e "${RED}[✗] File count mismatch!${NC}"
        echo "  Expected: $target_file_count, Got: $new_file_count"
        echo "  Aborting resize operation"
        # Cleanup
        wsl_umount_vhd "$temp_mount_point"
        wsl_detach_vhd "$new_vhd_path" "$new_uuid" ""
        wsl_delete_vhd "$new_vhd_path"
        exit 1
    fi
    
    if [[ $new_size_bytes -ne $target_size_bytes ]]; then
        echo -e "${YELLOW}[!] Warning: Size differs slightly (expected with filesystem metadata)${NC}"
        echo "  Difference: $((new_size_bytes - target_size_bytes)) bytes"
    fi
    
    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] Verification passed${NC}"
    [[ "$QUIET" == "false" ]] && echo
    
    # Unmount and detach target disk
    [[ "$QUIET" == "false" ]] && echo "Unmounting target disk..."
    if ! wsl_umount_vhd "$target_mount_point"; then
        echo -e "${RED}[✗] Failed to unmount target disk${NC}"
        exit 1
    fi
    
    # Get VHD names from tracking file for history
    local target_name=""
    local new_name=""
    if [[ -f "$DISK_TRACKING_FILE" ]] && command -v jq &> /dev/null; then
        local normalized_target=$(normalize_vhd_path "$target_vhd_path")
        local normalized_new=$(normalize_vhd_path "$new_vhd_path")
        target_name=$(jq -r --arg path "$normalized_target" '.mappings[$path].name // empty' "$DISK_TRACKING_FILE" 2>/dev/null)
        new_name=$(jq -r --arg path "$normalized_new" '.mappings[$path].name // empty' "$DISK_TRACKING_FILE" 2>/dev/null)
    fi
    
    if ! wsl_detach_vhd "$target_vhd_path" "$target_uuid" "$target_name"; then
        echo -e "${RED}[✗] Failed to detach target disk${NC}"
        # Cleanup on failure - detach new VHD
        wsl_detach_vhd "$new_vhd_path" "$new_uuid" "$new_name"
        exit 1
    fi
    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] Target disk detached${NC}"
    [[ "$QUIET" == "false" ]] && echo
    
    # Rename target VHD to backup
    local target_vhd_path_wsl=$(echo "$target_vhd_path" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\\\|/|g')
    local backup_vhd_path_wsl="${target_vhd_path_wsl%.vhdx}_bkp.vhdx"
    local backup_vhd_path_wsl="${backup_vhd_path_wsl%.vhd}_bkp.vhd"
    
    [[ "$QUIET" == "false" ]] && echo "Renaming target VHD to backup..."
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} mv '$target_vhd_path_wsl' '$backup_vhd_path_wsl'" >&2
    fi
    
    if mv "$target_vhd_path_wsl" "$backup_vhd_path_wsl" 2>/dev/null; then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] Target VHD renamed to backup${NC}"
        [[ "$QUIET" == "false" ]] && echo "  Backup: $backup_vhd_path_wsl"
    else
        echo -e "${RED}[✗] Failed to rename target VHD${NC}"
        exit 1
    fi
    [[ "$QUIET" == "false" ]] && echo
    
    # Unmount new disk temporarily
    [[ "$QUIET" == "false" ]] && echo "Unmounting new disk..."
    if ! wsl_umount_vhd "$temp_mount_point"; then
        echo -e "${RED}[✗] Failed to unmount new disk${NC}"
        exit 1
    fi
    
    if ! wsl_detach_vhd "$new_vhd_path" "$new_uuid" "$new_name"; then
        echo -e "${RED}[✗] Failed to detach new disk${NC}"
        # Cleanup on failure - reattach target VHD
        wsl_detach_vhd "$target_vhd_path" "$target_uuid" "$target_name"
        exit 1
    fi
    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] New disk detached${NC}"
    [[ "$QUIET" == "false" ]] && echo
    
    # Rename new VHD to target name
    local new_vhd_path_wsl=$(echo "$new_vhd_path" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\\\|/|g')
    
    [[ "$QUIET" == "false" ]] && echo "Renaming new VHD to target name..."
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} mv '$new_vhd_path_wsl' '$target_vhd_path_wsl'" >&2
    fi
    
    if mv "$new_vhd_path_wsl" "$target_vhd_path_wsl" 2>/dev/null; then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] New VHD renamed to target name${NC}"
    else
        echo -e "${RED}[✗] Failed to rename new VHD${NC}"
        exit 1
    fi
    [[ "$QUIET" == "false" ]] && echo
    
    # Mount the renamed VHD
    [[ "$QUIET" == "false" ]] && echo "Mounting resized VHD at $target_mount_point..."
    
    # Attach the VHD (it will get a new UUID since it was formatted)
    local old_uuids=($(wsl_get_disk_uuids))
    
    if ! wsl_attach_vhd "$target_vhd_path" "$target_vhd_name"; then
        echo -e "${RED}[✗] Failed to attach resized VHD${NC}"
        exit 1
    fi
    
    sleep 2  # Give system time to recognize the device
    
    # Find the new UUID
    local new_uuids=($(wsl_get_disk_uuids))
    declare -A seen_uuid
    for uuid in "${old_uuids[@]}"; do
        seen_uuid["$uuid"]=1
    done
    
    local final_uuid=""
    for uuid in "${new_uuids[@]}"; do
        if [[ -z "${seen_uuid[$uuid]}" ]]; then
            final_uuid="$uuid"
            break
        fi
    done
    
    if [[ -z "$final_uuid" ]]; then
        echo -e "${RED}[✗] Failed to detect UUID of resized VHD${NC}"
        exit 1
    fi
    
    # Mount the resized VHD
    if wsl_mount_vhd "$final_uuid" "$target_mount_point"; then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] Resized VHD mounted${NC}"
    else
        echo -e "${RED}[✗] Failed to mount resized VHD${NC}"
        exit 1
    fi
    [[ "$QUIET" == "false" ]] && echo
    
    # Display final disk info
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  Resized VHD Information"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  UUID: $final_uuid"
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$final_uuid"
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "  Files: $new_file_count"
    [[ "$QUIET" == "false" ]] && echo "  Data Size: $new_size_human"
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "  Backup VHD: $backup_vhd_path_wsl"
    [[ "$QUIET" == "false" ]] && echo "  (You can delete the backup once you verify the resized disk)"
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  Resize operation completed successfully"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        echo "$target_vhd_path: resized to $actual_size_str with UUID=$final_uuid"
    fi
}

# Function to format VHD
format_vhd_command() {
    # Parse format command arguments
    local format_name=""
    local format_uuid=""
    local default_fs="${DEFAULT_FILESYSTEM_TYPE:-ext4}"
    local format_type="$default_fs"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --name requires a value" >&2
                    return 1
                fi
                if ! validate_device_name "$2"; then
                    echo -e "${RED}Error: Invalid device name format: $2${NC}" >&2
                    echo "Device name must match pattern: sd[a-z]+ (e.g., sdd, sde)" >&2
                    exit 1
                fi
                format_name="$2"
                shift 2
                ;;
            --uuid)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --uuid requires a value" >&2
                    return 1
                fi
                if ! validate_uuid "$2"; then
                    echo -e "${RED}Error: Invalid UUID format: $2${NC}" >&2
                    echo "UUID must be in format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" >&2
                    exit 1
                fi
                format_uuid="$2"
                shift 2
                ;;
            --type)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --type requires a value" >&2
                    return 1
                fi
                if ! validate_filesystem_type "$2"; then
                    echo -e "${RED}Error: Invalid filesystem type: $2${NC}" >&2
                    echo "Supported types: ext2, ext3, ext4, xfs, btrfs, ntfs, vfat, exfat" >&2
                    exit 1
                fi
                format_type="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                echo "Use --help to see available options" >&2
                exit 1
                ;;
        esac
    done
    
    # Validate that at least name or UUID is provided
    if [[ -z "$format_name" && -z "$format_uuid" ]]; then
        echo -e "${RED}Error: Either --name or --uuid is required${NC}" >&2
        echo >&2
        echo "Usage: $0 format [OPTIONS]" >&2
        echo >&2
        echo "Options:" >&2
        echo "  --name NAME   - VHD device block name (e.g., sdd, sde)" >&2
        echo "  --uuid UUID   - VHD UUID" >&2
        local default_fs="${DEFAULT_FILESYSTEM_TYPE:-ext4}"
        echo "  --type TYPE   - Filesystem type [default: $default_fs]" >&2
        echo >&2
        echo "Examples:" >&2
        echo "  $0 format --name sdd --type ext4" >&2
        echo "  $0 format --uuid 57fd0f3a-4077-44b8-91ba-5abdee575293 --type ext4" >&2
        echo >&2
        echo "To find attached VHDs, run: $0 status --all" >&2
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Disk Format Operation"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo
    
    local device_name=""
    local target_identifier=""
    
    # Determine device name based on provided arguments
    if [[ -n "$format_uuid" ]]; then
        # Check if UUID exists and if it's already formatted
        if [[ "$DEBUG" == "true" ]]; then
            echo -e "${BLUE}[DEBUG]${NC} lsblk -f -J | jq -r --arg UUID '$format_uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'" >&2
        fi
        device_name=$(lsblk -f -J | jq -r --arg UUID "$format_uuid" '.blockdevices[] | select(.uuid == $UUID) | .name' 2>/dev/null)
        
        if [[ -z "$device_name" ]]; then
            echo -e "${RED}[✗] No device found with UUID: $format_uuid${NC}"
            echo
            echo "The UUID might be incorrect or the VHD is not attached."
            echo "To find attached VHDs, run: $0 status --all"
            exit 1
        fi
        
        # Validate device name format for security before use in mkfs
        if ! validate_device_name "$device_name"; then
            echo -e "${RED}Error: Invalid device name format: $device_name${NC}" >&2
            echo "Device name must match pattern: sd[a-z]+ (e.g., sdd, sde, sdaa)" >&2
            echo "This is a security check to prevent command injection." >&2
            exit 1
        fi
        
        # Warn user that disk is already formatted
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] WARNING: Device /dev/$device_name is already formatted${NC}"
        [[ "$QUIET" == "false" ]] && echo "  Current UUID: $format_uuid"
        [[ "$QUIET" == "false" ]] && echo
        [[ "$QUIET" == "false" ]] && echo "Formatting will destroy all existing data and generate a new UUID."
        
        if [[ "$QUIET" == "false" ]]; then
            echo -n "Are you sure you want to format /dev/$device_name? (yes/no): "
            read -r confirmation
            
            if [[ "$confirmation" != "yes" ]]; then
                echo "Format operation cancelled."
                exit 0
            fi
            echo
        fi
        
        target_identifier="UUID $format_uuid"
    else
        # Using device name directly
        device_name="$format_name"
        target_identifier="device name $format_name"
        
        # Validate device exists
        if [[ ! -b "/dev/$device_name" ]]; then
            echo -e "${RED}[✗] Block device /dev/$device_name does not exist${NC}"
            echo
            echo "Please check the device name is correct."
            echo "To find attached VHDs, run: $0 status --all"
            exit 1
        fi
        
        # Check if device has existing UUID (already formatted)
        local existing_uuid=$(sudo blkid -s UUID -o value "/dev/$device_name" 2>/dev/null)
        if [[ -n "$existing_uuid" ]]; then
            [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] WARNING: Device /dev/$device_name is already formatted${NC}"
            [[ "$QUIET" == "false" ]] && echo "  Current UUID: $existing_uuid"
            [[ "$QUIET" == "false" ]] && echo
            [[ "$QUIET" == "false" ]] && echo "Formatting will destroy all existing data and generate a new UUID."
            
            if [[ "$QUIET" == "false" ]]; then
                echo -n "Are you sure you want to format /dev/$device_name? (yes/no): "
                read -r confirmation
                
                if [[ "$confirmation" != "yes" ]]; then
                    echo "Format operation cancelled."
                    exit 0
                fi
                echo
            fi
        else
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] Device /dev/$device_name is not formatted${NC}"
            [[ "$QUIET" == "false" ]] && echo
        fi
    fi
    
    [[ "$QUIET" == "false" ]] && echo "Formatting device /dev/$device_name with $format_type..."
    [[ "$QUIET" == "false" ]] && echo "  Target: $target_identifier"
    [[ "$QUIET" == "false" ]] && echo
    
    # Format using helper function
    local new_uuid=$(format_vhd "$device_name" "$format_type")
    if [[ $? -ne 0 || -z "$new_uuid" ]]; then
        echo -e "${RED}[✗] Failed to format device /dev/$device_name${NC}"
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD formatted successfully${NC}"
    [[ "$QUIET" == "false" ]] && echo "  Device: /dev/$device_name"
    [[ "$QUIET" == "false" ]] && echo "  New UUID: $new_uuid"
    [[ "$QUIET" == "false" ]] && echo "  Filesystem: $format_type"
    
    # Note: We cannot automatically update path→UUID mapping here because format
    # command doesn't require path parameter. The mapping will be updated when
    # attach/mount operations are performed with the new UUID.
    
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$new_uuid"
    
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  Format operation completed"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        echo "/dev/$device_name: formatted with UUID=$new_uuid"
    fi
}

# Function to attach VHD
attach_vhd() {
    # Parse attach command arguments
    local attach_path=""
    local attach_name="$VHD_NAME"
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --path requires a value" >&2
                    return 1
                fi
                if ! validate_windows_path "$2"; then
                    echo -e "${RED}Error: Invalid path format: $2${NC}" >&2
                    echo "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)" >&2
                    exit 1
                fi
                attach_path="$2"
                shift 2
                ;;
            --name)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo "Error: --name requires a value" >&2
                    return 1
                fi
                if ! validate_vhd_name "$2"; then
                    echo -e "${RED}Error: Invalid VHD name format: $2${NC}" >&2
                    echo "VHD name must contain only alphanumeric characters, hyphens, and underscores" >&2
                    exit 1
                fi
                attach_name="$2"
                shift 2
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                echo "Use --help to see available options" >&2
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$attach_path" ]]; then
        echo "Error: VHD path is required. Use --path option." >&2
        exit 1
    fi
    
    # Convert Windows path to WSL path to check if VHD exists
    local vhd_path_wsl=$(echo "$attach_path" | sed 's|^\([A-Za-z]\):|/mnt/\L\1|' | sed 's|\\|/|g')
    if [[ ! -e "$vhd_path_wsl" ]]; then
        echo "Error: VHD file does not exist: $attach_path" >&2
        echo "  (WSL path: $vhd_path_wsl)" >&2
        exit 1
    fi
    
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Disk Attach Operation"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo
    
    # Take snapshot of current UUIDs and block devices before attaching
    local old_uuids=($(wsl_get_disk_uuids))
    local old_devs=($(wsl_get_block_devices))
    
    # Try to attach the VHD (will succeed if not attached, fail silently if already attached)
    local attach_uuid=""
    local newly_attached=false
    
    if wsl_attach_vhd "$attach_path" "$attach_name" 2>/dev/null; then
        newly_attached=true
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD attached to WSL${NC}"
        [[ "$QUIET" == "false" ]] && echo "  Path: $attach_path"
        [[ "$QUIET" == "false" ]] && echo "  Name: $attach_name"
        [[ "$QUIET" == "false" ]] && echo
        
        # Give the system time to recognize the new device
        sleep 2
        
        # Take new snapshot to detect the new device
        local new_uuids=($(wsl_get_disk_uuids))
        local new_devs=($(wsl_get_block_devices))
        
        # Build lookup table for old UUIDs
        declare -A seen_uuid
        for uuid in "${old_uuids[@]}"; do
            seen_uuid["$uuid"]=1
        done
        
        # Find the new UUID
        for uuid in "${new_uuids[@]}"; do
            if [[ -z "${seen_uuid[$uuid]}" ]]; then
                attach_uuid="$uuid"
                break
            fi
        done
        
        if [[ -z "$attach_uuid" ]]; then
            [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] Warning: Could not automatically detect UUID${NC}"
            [[ "$QUIET" == "false" ]] && echo "  The VHD was attached successfully but UUID detection failed."
            [[ "$QUIET" == "false" ]] && echo "  You can find the UUID using: ./disk_management.sh status --all"
        else
            # Find the device name
            if [[ "$DEBUG" == "true" ]]; then
                echo -e "${BLUE}[DEBUG]${NC} lsblk -f -J | jq -r --arg UUID '$attach_uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'" >&2
            fi
            local new_dev=$(lsblk -f -J | jq -r --arg UUID "$attach_uuid" '.blockdevices[] | select(.uuid == $UUID) | .name' 2>/dev/null)
            
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] Device detected${NC}"
            [[ "$QUIET" == "false" ]] && echo "  UUID: $attach_uuid"
            [[ "$QUIET" == "false" ]] && [[ -n "$new_dev" ]] && echo "  Device: /dev/$new_dev"
            
            # Save mapping to tracking file with VHD name
            save_vhd_mapping "$attach_path" "$attach_uuid" "" "$attach_name"
        fi
    else
        # Attachment failed - VHD might already be attached
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD attachment failed - checking if already attached...${NC}"
        [[ "$QUIET" == "false" ]] && echo
        
        # Try to find the UUID with multi-VHD safety
        local discovery_result
        attach_uuid=$(wsl_find_uuid_by_path "$attach_path" 2>&1)
        discovery_result=$?
        
        if [[ $discovery_result -eq 2 ]]; then
            # Multiple VHDs detected
            echo -e "${RED}[✗] Cannot determine UUID: Multiple VHDs are attached${NC}"
            echo
            echo "Run '$0 status --all' to see all attached VHDs."
            exit 1
        elif [[ -n "$attach_uuid" ]] && wsl_is_vhd_attached "$attach_uuid"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD is already attached to WSL${NC}"
            [[ "$QUIET" == "false" ]] && echo "  UUID: $attach_uuid"
            
            # Get device name
            if [[ "$DEBUG" == "true" ]]; then
                echo -e "${BLUE}[DEBUG]${NC} lsblk -f -J | jq -r --arg UUID '$attach_uuid' '.blockdevices[] | select(.uuid == \$UUID) | .name'" >&2
            fi
            local dev_name=$(lsblk -f -J | jq -r --arg UUID "$attach_uuid" '.blockdevices[] | select(.uuid == $UUID) | .name' 2>/dev/null)
            [[ "$QUIET" == "false" ]] && [[ -n "$dev_name" ]] && echo "  Device: /dev/$dev_name"
            
            # Save mapping to tracking file (idempotent - updates if exists) with VHD name
            save_vhd_mapping "$attach_path" "$attach_uuid" "" "$attach_name"
        else
            echo -e "${RED}[✗] Failed to attach VHD${NC}" >&2
            echo "  The VHD might already be attached with a different name or path." >&2
            echo "  Try running: ./disk_management.sh status --all" >&2
            exit 1
        fi
    fi
    
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && [[ -n "$attach_uuid" ]] && wsl_get_vhd_info "$attach_uuid"
    
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  Attach operation completed"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if [[ -n "$attach_uuid" ]]; then
            echo "$attach_path ($attach_uuid): attached"
        else
            echo "$attach_path: attached (UUID unknown)"
        fi
    fi
}

# Function to show detach history
history_vhd() {
    # Parse history command arguments
    local default_limit="${DEFAULT_HISTORY_LIMIT:-10}"
    local limit="$default_limit"
    local show_path=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --limit requires a value${NC}" >&2
                    return 1
                fi
                limit="$2"
                shift 2
                ;;
            --path)
                if [[ -z "$2" || "$2" == --* ]]; then
                    echo -e "${RED}Error: --path requires a value${NC}" >&2
                    return 1
                fi
                if ! validate_windows_path "$2"; then
                    echo -e "${RED}Error: Invalid path format: $2${NC}" >&2
                    echo "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)" >&2
                    return 1
                fi
                show_path="$2"
                shift 2
                ;;
            *)
                echo -e "${RED}Error: Unknown history option '$1'${NC}"
                echo
                show_usage
                ;;
        esac
    done
    
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Detach History"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo
    
    if [[ -n "$show_path" ]]; then
        # Show history for specific path
        local history_json=$(get_last_detach_for_path "$show_path")
        
        if [[ -n "$history_json" ]]; then
            if [[ "$QUIET" == "true" ]]; then
                echo "$history_json"
            else
                local path=$(echo "$history_json" | jq -r '.path')
                local uuid=$(echo "$history_json" | jq -r '.uuid')
                local name=$(echo "$history_json" | jq -r '.name // empty')
                local timestamp=$(echo "$history_json" | jq -r '.timestamp')
                
                echo "Path: $path"
                echo "UUID: $uuid"
                [[ -n "$name" ]] && echo "Name: $name"
                echo "Last detached: $timestamp"
            fi
        else
            [[ "$QUIET" == "false" ]] && echo "No detach history found for path: $show_path"
            [[ "$QUIET" == "true" ]] && echo "{}"
        fi
    else
        # Show recent history
        local history_json=$(get_detach_history "$limit")
        
        if [[ "$QUIET" == "true" ]]; then
            echo "$history_json"
        else
            local count=$(echo "$history_json" | jq 'length')
            
            if [[ "$count" -eq 0 ]]; then
                echo "No detach history available"
            else
                echo "Showing last $count detach events:"
                echo
                
                echo "$history_json" | jq -r '.[] | 
                    "Path: \(.path)\n" +
                    "UUID: \(.uuid)\n" +
                    (if .name and .name != "" then "Name: \(.name)\n" else "" end) +
                    "Timestamp: \(.timestamp)\n"'
            fi
        fi
    fi
    
    [[ "$QUIET" == "false" ]] && echo "========================================"
}

# Function to mount VHD
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
        -d|--debug)
            DEBUG=true
            shift
            ;;
        -h|--help|help)
            show_usage
            ;;
        attach|format|mount|umount|unmount|detach|status|create|delete|resize|history)
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
    attach)
        attach_vhd "$@"  # Pass remaining arguments to attach_vhd
        ;;
    format)
        format_vhd_command "$@"  # Pass remaining arguments to format_vhd_command
        ;;
    mount)
        mount_vhd "$@"  # Pass remaining arguments to mount_vhd
        ;;
    umount|unmount)
        umount_vhd "$@"  # Pass remaining arguments to umount_vhd
        ;;
    detach)
        detach_vhd "$@"  # Pass remaining arguments to detach_vhd
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
    resize)
        resize_vhd "$@"  # Pass remaining arguments to resize_vhd
        ;;
    history)
        history_vhd "$@"  # Pass remaining arguments to history_vhd
        ;;
    *)
        echo -e "${RED}Error: No command specified${NC}"
        echo
        show_usage
        ;;
esac
