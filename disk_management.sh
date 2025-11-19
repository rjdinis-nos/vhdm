#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source WSL helper functions
source "$SCRIPT_DIR/wsl_helpers.sh"

# Configuration
VHD_PATH="C:/aNOS/VMs/wsl_disks/share.vhdx"
VHD_UUID="57fd0f3a-4077-44b8-91ba-5abdee575293"
MOUNT_POINT="/home/rjdinis/share"
VHD_NAME="share"

# Quiet mode flag
QUIET=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS] [mount|umount|status]"
    echo
    echo "Options:"
    echo "  -q, --quiet  - Run in quiet mode (minimal output)"
    echo
    echo "Commands:"
    echo "  mount   - Attach and mount the VHD disk"
    echo "  umount  - Unmount and detach the VHD disk"
    echo "  status  - Show current VHD disk status"
    echo
    exit 0
}

# Function to show status
show_status() {
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Disk Status"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  Path: $VHD_PATH"
    [[ "$QUIET" == "false" ]] && echo "  UUID: $VHD_UUID"
    [[ "$QUIET" == "false" ]] && echo "  Mount Point: $MOUNT_POINT"
    [[ "$QUIET" == "false" ]] && echo
    
    if wsl_is_vhd_attached "$VHD_UUID"; then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD is attached to WSL${NC}"
        [[ "$QUIET" == "false" ]] && echo
        [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$VHD_UUID"
        [[ "$QUIET" == "false" ]] && echo
        
        if wsl_is_vhd_mounted "$VHD_UUID"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD is mounted${NC}"
            [[ "$QUIET" == "true" ]] && echo "$VHD_PATH ($VHD_UUID): attached,mounted"
        else
            [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is attached but not mounted${NC}"
            [[ "$QUIET" == "true" ]] && echo "$VHD_PATH ($VHD_UUID): attached"
        fi
    else
        [[ "$QUIET" == "false" ]] && echo -e "${RED}[✗] VHD is not attached to WSL${NC}"
        [[ "$QUIET" == "true" ]] && echo "$VHD_PATH ($VHD_UUID): detached"
    fi
    [[ "$QUIET" == "false" ]] && echo "========================================"
}

# Function to mount VHD
mount_vhd() {
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Disk Mount Operation"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo
    
    if wsl_is_vhd_attached "$VHD_UUID"; then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD is already attached to WSL${NC}"
        [[ "$QUIET" == "false" ]] && echo
        [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$VHD_UUID"
        [[ "$QUIET" == "false" ]] && echo
        
        if wsl_is_vhd_mounted "$VHD_UUID"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD is already mounted${NC}"
            [[ "$QUIET" == "false" ]] && echo "Nothing to do."
        else
            [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is attached but not mounted${NC}"
            
            # Create mount point if it doesn't exist
            if [[ ! -d "$MOUNT_POINT" ]]; then
                [[ "$QUIET" == "false" ]] && echo "Creating mount point: $MOUNT_POINT"
                mkdir -p "$MOUNT_POINT"
            fi
            
            [[ "$QUIET" == "false" ]] && echo "Mounting VHD to $MOUNT_POINT..."
            if wsl_mount_vhd_by_uuid "$VHD_UUID" "$MOUNT_POINT"; then
                [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD mounted successfully${NC}"
            else
                echo -e "${RED}[✗] Failed to mount VHD${NC}"
                exit 1
            fi
        fi
    else
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is not attached to WSL${NC}"
        [[ "$QUIET" == "false" ]] && echo "Attaching VHD to WSL..."
        
        if wsl_attach_vhd "$VHD_PATH" "$VHD_NAME"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD attached successfully${NC}"
            sleep 2  # Give the system time to recognize the device
            [[ "$QUIET" == "false" ]] && echo
            
            # Create mount point if it doesn't exist
            if [[ ! -d "$MOUNT_POINT" ]]; then
                [[ "$QUIET" == "false" ]] && echo "Creating mount point: $MOUNT_POINT"
                mkdir -p "$MOUNT_POINT"
            fi
            
            [[ "$QUIET" == "false" ]] && echo "Mounting VHD to $MOUNT_POINT..."
            if wsl_mount_vhd_by_uuid "$VHD_UUID" "$MOUNT_POINT"; then
                [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD mounted successfully${NC}"
            else
                echo -e "${RED}[✗] Failed to mount VHD${NC}"
                exit 1
            fi
        else
            echo -e "${RED}[✗] Failed to attach VHD to WSL${NC}"
            exit 1
        fi
    fi

    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$VHD_UUID"
    
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  Mount operation completed"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if wsl_is_vhd_mounted "$VHD_UUID"; then
            echo "$VHD_PATH ($VHD_UUID): attached,mounted"
        else
            echo "$VHD_PATH ($VHD_UUID): mount failed"
        fi
    fi
}

# Function to unmount VHD
umount_vhd() {
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  VHD Disk Unmount Operation"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo
    
    if ! wsl_is_vhd_attached "$VHD_UUID"; then
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is not attached to WSL${NC}"
        [[ "$QUIET" == "false" ]] && echo "Nothing to do."
        [[ "$QUIET" == "false" ]] && echo "========================================"
        return 0
    fi
    
    [[ "$QUIET" == "false" ]] && echo -e "${BLUE}[i] VHD is attached to WSL${NC}"
    [[ "$QUIET" == "false" ]] && echo
    
    # First, unmount from filesystem if mounted
    if wsl_is_vhd_mounted "$VHD_UUID"; then
        [[ "$QUIET" == "false" ]] && echo "Unmounting VHD from $MOUNT_POINT..."
        if wsl_unmount_vhd "$MOUNT_POINT"; then
            [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD unmounted successfully${NC}"
        else
            echo -e "${RED}[✗] Failed to unmount VHD${NC}"
            echo "Tip: Make sure no processes are using the mount point"
            exit 1
        fi
    else
        [[ "$QUIET" == "false" ]] && echo -e "${YELLOW}[!] VHD is not mounted to filesystem${NC}"
    fi
    
    # Then, detach from WSL
    [[ "$QUIET" == "false" ]] && echo "Detaching VHD from WSL..."
    if wsl_detach_vhd "$VHD_PATH"; then
        [[ "$QUIET" == "false" ]] && echo -e "${GREEN}[✓] VHD detached successfully${NC}"
    else
        echo -e "${RED}[✗] Failed to detach VHD from WSL${NC}"
        exit 1
    fi

    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && wsl_get_vhd_info "$VHD_UUID"
    
    [[ "$QUIET" == "false" ]] && echo
    [[ "$QUIET" == "false" ]] && echo "========================================"
    [[ "$QUIET" == "false" ]] && echo "  Unmount operation completed"
    [[ "$QUIET" == "false" ]] && echo "========================================"
    
    if [[ "$QUIET" == "true" ]]; then
        if ! wsl_is_vhd_attached "$VHD_UUID"; then
            echo "$VHD_PATH ($VHD_UUID): detached"
        else
            echo "$VHD_PATH ($VHD_UUID): umount failed"
        fi
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
        mount|umount|unmount|status)
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
        mount_vhd
        ;;
    umount|unmount)
        umount_vhd
        ;;
    status)
        show_status
        ;;
    *)
        echo -e "${RED}Error: No command specified${NC}"
        echo
        show_usage
        ;;
esac
