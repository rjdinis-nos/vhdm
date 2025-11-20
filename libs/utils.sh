#!/bin/bash

# Utility functions for disk management scripts

# Helper function to calculate total size of files in directory (in bytes)
# Args: $1 - Directory path
# Returns: Size in bytes
get_directory_size_bytes() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        echo "0"
        return 1
    fi
    
    # Use du to get size in bytes (--bytes or -b)
    local size_bytes
    if [[ "$DEBUG" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} du -sb '$dir' | awk '{print \$1}'" >&2
    fi
    size_bytes=$(du -sb "$dir" 2>/dev/null | awk '{print $1}')
    
    if [[ -z "$size_bytes" ]]; then
        echo "0"
        return 1
    fi
    
    echo "$size_bytes"
    return 0
}

# Helper function to convert size string to bytes
# Args: $1 - Size string (e.g., "5G", "500M", "10G")
# Returns: Size in bytes
convert_size_to_bytes() {
    local size_str="$1"
    local num=$(echo "$size_str" | sed 's/[^0-9.]//g')
    local unit=$(echo "$size_str" | sed 's/[0-9.]//g' | tr '[:lower:]' '[:upper:]')
    
    # Remove decimal point for bash arithmetic
    local num_int=$(echo "$num" | cut -d. -f1)
    [[ -z "$num_int" ]] && num_int=0
    
    case "$unit" in
        K|KB)
            echo $((num_int * 1024))
            ;;
        M|MB)
            echo $((num_int * 1024 * 1024))
            ;;
        G|GB)
            echo $((num_int * 1024 * 1024 * 1024))
            ;;
        T|TB)
            echo $((num_int * 1024 * 1024 * 1024 * 1024))
            ;;
        *)
            # Assume bytes if no unit
            echo "$num_int"
            ;;
    esac
}

# Helper function to convert bytes to human readable format
# Args: $1 - Size in bytes
# Returns: Human readable size string
bytes_to_human() {
    local bytes="$1"
    
    if [[ "$USE_BC" == "true" ]] && command -v bc >/dev/null 2>&1; then
        # Use bc for precise decimal calculations
        if [[ $bytes -lt 1024 ]]; then
            echo "${bytes}B"
        elif [[ $bytes -lt $((1024 * 1024)) ]]; then
            echo "$(echo "scale=2; $bytes / 1024" | bc)KB"
        elif [[ $bytes -lt $((1024 * 1024 * 1024)) ]]; then
            echo "$(echo "scale=2; $bytes / (1024 * 1024)" | bc)MB"
        else
            echo "$(echo "scale=2; $bytes / (1024 * 1024 * 1024)" | bc)GB"
        fi
    else
        # Fallback to bash arithmetic (no decimal precision)
        if [[ $bytes -lt 1024 ]]; then
            echo "${bytes}B"
        elif [[ $bytes -lt $((1024 * 1024)) ]]; then
            echo "$((bytes / 1024))KB"
        elif [[ $bytes -lt $((1024 * 1024 * 1024)) ]]; then
            echo "$((bytes / (1024 * 1024)))MB"
        else
            echo "$((bytes / (1024 * 1024 * 1024)))GB"
        fi
    fi
}
