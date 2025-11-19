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

# Function to show usage
show_usage() {
    echo "Usage: $0 [mount|umount|status]"
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
    echo "========================================"
    echo "  VHD Disk Status"
    echo "========================================"
    echo "  Path: $VHD_PATH"
    echo "  UUID: $VHD_UUID"
    echo "  Mount Point: $MOUNT_POINT"
    echo
    
    if wsl_is_vhd_attached "$VHD_UUID"; then
        echo -e "${GREEN}[✓] VHD is attached to WSL${NC}"
        echo
        wsl_get_vhd_info "$VHD_UUID"
        echo
        
        if wsl_is_vhd_mounted "$VHD_UUID"; then
            echo -e "${GREEN}[✓] VHD is mounted${NC}"
        else
            echo -e "${YELLOW}[!] VHD is attached but not mounted${NC}"
        fi
    else
        echo -e "${RED}[✗] VHD is not attached to WSL${NC}"
    fi
    echo "========================================"
}

# Function to mount VHD
mount_vhd() {
    echo "========================================"
    echo "  VHD Disk Mount Operation"
    echo "========================================"
    echo
    
    if wsl_is_vhd_attached "$VHD_UUID"; then
        echo -e "${GREEN}[✓] VHD is already attached to WSL${NC}"
        echo
        wsl_get_vhd_info "$VHD_UUID"
        echo
        
        if wsl_is_vhd_mounted "$VHD_UUID"; then
            echo -e "${GREEN}[✓] VHD is already mounted${NC}"
            echo "Nothing to do."
        else
            echo -e "${YELLOW}[!] VHD is attached but not mounted${NC}"
            
            # Create mount point if it doesn't exist
            if [[ ! -d "$MOUNT_POINT" ]]; then
                echo "Creating mount point: $MOUNT_POINT"
                mkdir -p "$MOUNT_POINT"
            fi
            
            echo "Mounting VHD to $MOUNT_POINT..."
            if wsl_mount_vhd_by_uuid "$VHD_UUID" "$MOUNT_POINT"; then
                echo -e "${GREEN}[✓] VHD mounted successfully${NC}"
            else
                echo -e "${RED}[✗] Failed to mount VHD${NC}"
                exit 1
            fi
        fi
    else
        echo -e "${YELLOW}[!] VHD is not attached to WSL${NC}"
        echo "Attaching VHD to WSL..."
        
        if wsl_attach_vhd "$VHD_PATH" "$VHD_NAME"; then
            echo -e "${GREEN}[✓] VHD attached successfully${NC}"
            sleep 2  # Give the system time to recognize the device
            echo
            
            # Create mount point if it doesn't exist
            if [[ ! -d "$MOUNT_POINT" ]]; then
                echo "Creating mount point: $MOUNT_POINT"
                mkdir -p "$MOUNT_POINT"
            fi
            
            echo "Mounting VHD to $MOUNT_POINT..."
            if wsl_mount_vhd_by_uuid "$VHD_UUID" "$MOUNT_POINT"; then
                echo -e "${GREEN}[✓] VHD mounted successfully${NC}"
            else
                echo -e "${RED}[✗] Failed to mount VHD${NC}"
                exit 1
            fi
        else
            echo -e "${RED}[✗] Failed to attach VHD to WSL${NC}"
            exit 1
        fi
    fi

    echo
    wsl_get_vhd_info "$VHD_UUID"
    
    echo
    echo "========================================"
    echo "  Mount operation completed"
    echo "========================================"
}

# Function to unmount VHD
umount_vhd() {
    echo "========================================"
    echo "  VHD Disk Unmount Operation"
    echo "========================================"
    echo
    
    if ! wsl_is_vhd_attached "$VHD_UUID"; then
        echo -e "${YELLOW}[!] VHD is not attached to WSL${NC}"
        echo "Nothing to do."
        echo "========================================"
        return 0
    fi
    
    echo -e "${BLUE}[i] VHD is attached to WSL${NC}"
    echo
    
    # First, unmount from filesystem if mounted
    if wsl_is_vhd_mounted "$VHD_UUID"; then
        echo "Unmounting VHD from $MOUNT_POINT..."
        if wsl_unmount_vhd "$MOUNT_POINT"; then
            echo -e "${GREEN}[✓] VHD unmounted successfully${NC}"
        else
            echo -e "${RED}[✗] Failed to unmount VHD${NC}"
            echo "Tip: Make sure no processes are using the mount point"
            exit 1
        fi
    else
        echo -e "${YELLOW}[!] VHD is not mounted to filesystem${NC}"
    fi
    
    # Then, detach from WSL
    echo "Detaching VHD from WSL..."
    if wsl_detach_vhd "$VHD_PATH"; then
        echo -e "${GREEN}[✓] VHD detached successfully${NC}"
    else
        echo -e "${RED}[✗] Failed to detach VHD from WSL${NC}"
        exit 1
    fi

    echo
    wsl_get_vhd_info "$VHD_UUID"
    
    echo
    echo "========================================"
    echo "  Unmount operation completed"
    echo "========================================"
}

# Main script logic
if [[ $# -eq 0 ]]; then
    show_usage
fi

COMMAND="$1"

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
    -h|--help|help)
        show_usage
        ;;
    *)
        echo -e "${RED}Error: Unknown command '$COMMAND'${NC}"
        echo
        show_usage
        ;;
esac
