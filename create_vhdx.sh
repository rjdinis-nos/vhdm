#!/bin/bash

DISK_NAME=mydisk.vhdx

get_block_dev() {
    mapfile -t udevs < <(sudo lsblk -J | jq -r '.blockdevices[].name')
    echo "${udevs[@]}"
}

# Function to get current disk UUIDs as an array
get_disk_uuids() {
    # blkid lists UUIDs for all block devices
    # Remove quotes and store as array
    mapfile -t uuids < <(sudo blkid -s UUID -o value)
    echo "${uuids[@]}" | tr -d '"'
}

# Take first snapshot
OLD_UUID=($(get_disk_uuids))
echo "Old UUIDs: ${OLD_UUID[@]}"
OLD_UDEV=($(get_block_dev))
echo "OLD UDEVs: ${OLD_UDEV[@]}"

# Install quemu-img if not exists in system
if [[ $(pacman -Qq | grep -e "^qemu-img$" | wc -l) -eq "0" ]]; then sudo pacman -Syu; sudo pacman -Sy qemu-img; fi

# Create VHD and mount if not exists
if [[ ! -e /mnt/c/aNOS/VMs/wsl_disks/mydisk.vhdx ]]; then
    qemu-img create -f vhdx /mnt/c/aNOS/VMs/wsl_disks/mydisk.vhdx 1G
    #qemu-img info /mnt/c/aNOS/VMs/wsl_disks/mydisk.vhdx    
    wsl.exe --mount --vhd "C:\aNOS\VMs\wsl_disks\mydisk.vhdx" --bare --name share
    #sleep 5
fi

# Build lookup tables for OLD DEVs and UUIDs
declare -A seen_dev
for dev in "${OLD_UDEV[@]}"; do
    seen_dev["$dev"]=1
done
declare -A seen_uuid
for uuid in "${OLD_UUID[@]}"; do
    seen_uuid["$uuid"]=1
done

# Take second snapshot
NEW_UUID=($(get_disk_uuids))
echo "New UUIDs: ${NEW_UUID[@]}"
NEW_UDEV=($(get_block_dev))
echo "NEW UDEVs: ${NEW_UDEV[@]}"

# Compare and print only new DEVs and UUIDs
declare new_dev
echo "Newly detected DEVs:"
for dev in "${NEW_UDEV[@]}"; do
    [[ -z "${seen_dev[$dev]}" ]] && echo "$dev"
    new_dev=$dev
done
echo "Newly detected UUIDs:"
for uuid in "${NEW_UUID[@]}"; do
    [[ -z "${seen_uuid[$uuid]}" ]] && echo "$uuid"
done

# Format new block disk
sudo mkfs -t ext4 /dev/$new_dev

#new_uuid=$(lsblk -f -J | jq '.blockdevices[] | select(.name == $dev) | .uuid')
#sudo mount UUID=$newuuid /home/rjdinis/mydisk

#name=$(lsblk -f -J | jq '.blockdevices[] | select(.uuid == $new_uuid) | .name')
#fsavail=$(lsblk -f -J | jq '.blockdevices[] | select(.uuid == $new_uuid) | .fsavail')
#fsuse=$(lsblk -f -J | jq '.blockdevices[] | select(.uuid == $new_uuid) | ."fsuse%"')
#mountpoints=$(lsblk -f -J | jq '.blockdevices[] | select(.uuid == $new_uuid) | .mountpoints[]')

#echo "Disk mounted: $name $fsavail $fsuse $mountpoints"
echo


