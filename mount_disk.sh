#!/usr/bin/env bash

# mount_disk.sh
# Ensures a VHD is attached and mounted at the specified location
# Usage: ./mount_disk.sh --mount-point <path> --disk-path <path>

set -e

# Get script directory for sourcing helpers
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration file
if [[ -f "$SCRIPT_DIR/config.sh" ]]; then
    source "$SCRIPT_DIR/config.sh"
fi

source "$SCRIPT_DIR/libs/utils.sh"
source "$SCRIPT_DIR/libs/wsl_helpers.sh"

# Initialize variables
MOUNT_POINT=""
DISK_PATH=""
QUIET="${QUIET:-false}"
DEBUG="${DEBUG:-false}"

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
            if ! validate_mount_point "$2"; then
                log_error "Invalid mount point format: $2"
                log_info "Mount point must be an absolute path (e.g., /mnt/data)"
                exit 1
            fi
            MOUNT_POINT="$2"
            shift 2
            ;;
        --disk-path)
            if ! validate_windows_path "$2"; then
                log_error "Invalid path format: $2"
                log_info "Path must be a valid Windows path (e.g., C:/path/to/file.vhdx)"
                exit 1
            fi
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
            log_error "Unknown argument: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$MOUNT_POINT" ]]; then
    log_error "--mount-point is required"
    show_usage
    exit 1
fi

if [[ -z "$DISK_PATH" ]]; then
    log_error "--disk-path is required"
    show_usage
    exit 1
fi

# Convert Windows path to WSL path for file existence check
WSL_DISK_PATH=$(wsl_convert_path "$DISK_PATH")

# Check if VHD file exists
if [[ ! -f "$WSL_DISK_PATH" ]]; then
    log_error "VHD file not found at $WSL_DISK_PATH"
    exit 1
fi

# Check if already mounted at the specified mount point
if [[ -d "$MOUNT_POINT" ]] && mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    log_success "Disk already mounted at $MOUNT_POINT"
    exit 0
fi

log_info "Disk not mounted. Checking attachment status..."

# Try to find UUID by path (if already attached)
# Use Windows path format (DISK_PATH) not WSL path format (WSL_DISK_PATH)
# because wsl_find_uuid_by_path expects Windows path format for tracking file lookup
local discovery_result
UUID=$(wsl_find_uuid_by_path "$DISK_PATH" 2>&1)
discovery_result=$?

# If not attached, attach it now
if [[ $discovery_result -ne 0 ]] || [[ -z "$UUID" ]]; then
    log_info "Attaching VHD: $DISK_PATH"
    
    # Generate a name for the attachment
    
    # Capture state before attach for snapshot-based detection
    local old_uuids=($(wsl_get_disk_uuids))
    
    # Attach the VHD
    if ! wsl_attach_vhd "$DISK_PATH" 2>/dev/null; then
        log_info "Note: VHD may already be attached, continuing..."
    fi
    
    # Detect new UUID using snapshot-based detection
    UUID=$(detect_new_uuid_after_attach "old_uuids")
    
    # If still not found, try path-based discovery again (VHD might have been attached)
    if [[ -z "$UUID" ]]; then
        UUID=$(wsl_find_uuid_by_path "$DISK_PATH" 2>&1)
        discovery_result=$?
        
        # Handle discovery result with consistent error handling
        # Note: We use handle_uuid_discovery_result for consistent error messages,
        # but mount_disk.sh is a standalone script, so we need to handle exit ourselves
        if [[ $discovery_result -eq 2 ]]; then
            log_error "Multiple VHDs attached. Cannot determine which one to mount."
            log_info "Please detach other VHDs first or use disk_management.sh with explicit --uuid."
            exit 1
        elif [[ -z "$UUID" ]]; then
            log_error "Failed to detect UUID after attaching VHD"
            exit 1
        fi
    fi
    
    log_success "VHD attached (UUID: $UUID)"
else
    # VHD already attached - verify UUID is valid
    if [[ $discovery_result -eq 2 ]]; then
        log_error "Multiple VHDs attached. Cannot determine which one to mount."
        log_info "Please detach other VHDs first or use disk_management.sh with explicit --uuid."
        exit 1
    fi
    log_success "VHD already attached (UUID: $UUID)"
fi

# Check if already mounted (might be mounted elsewhere)
if wsl_is_vhd_mounted "$UUID"; then
    CURRENT_MOUNT=$(wsl_get_vhd_mount_point "$UUID")
    if [[ "$CURRENT_MOUNT" == "$MOUNT_POINT" ]]; then
        log_success "Disk already mounted at $MOUNT_POINT"
        exit 0
    else
        log_success "Disk already mounted at $CURRENT_MOUNT"
        exit 0
    fi
fi

# Mount the disk
log_info "Mounting disk at $MOUNT_POINT..."

# Create mount point if it doesn't exist
if [[ ! -d "$MOUNT_POINT" ]]; then
    if ! create_mount_point "$MOUNT_POINT"; then
        log_error "Failed to create mount point"
        exit 1
    fi
fi

# Mount by UUID
if ! mount_filesystem "$UUID" "$MOUNT_POINT"; then
    log_error "Failed to mount disk"
    exit 1
fi

log_success "Disk successfully mounted at $MOUNT_POINT"
exit 0
