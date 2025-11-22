# VHD Resize Command

## Overview

The `resize` command allows you to resize an existing VHD disk by creating a new disk with the specified size, migrating all data, and replacing the original disk with a backup.

## Usage

```bash
./disk_management.sh resize --mount-point <PATH> --size <SIZE>
```

## Required Options

- `--mount-point PATH` - The mount point of the target disk to resize
- `--size SIZE` - The new disk size (e.g., 5G, 10G, 100M)

## How It Works

The resize operation performs the following steps:

1. **Validate Target Disk**: Checks if the target mount point exists and has a mounted VHD
2. **Calculate Data Size**: Determines the total size of all files in the target disk
3. **Determine New Size**: 
   - If `--size` is larger than data + 30%: uses specified size
   - If `--size` is smaller than data + 30%: uses data + 30% instead
4. **Create New VHD**: Creates a new VHD with temporary name (`disk_temp.vhdx`)
5. **Mount New VHD**: Mounts the new VHD at `<mount-point>_temp`
6. **Copy Data**: Uses `rsync -a` to copy all files preserving permissions and attributes
7. **Verify Migration**: Compares file count and total size between source and destination
8. **Unmount Target**: Unmounts and detaches the original VHD
9. **Rename Original**: Renames original VHD to `<name>_bkp.vhdx`
10. **Rename New**: Renames new VHD to original name
11. **Mount Resized**: Attaches and mounts the resized VHD at original mount point
12. **Display Info**: Shows final disk information including UUID and backup location

## Example

```bash
# Resize a disk mounted at /home/user/disk to 10GB
./disk_management.sh resize --mount-point /home/user/disk --size 10G

# Quiet mode
./disk_management.sh -q resize --mount-point /mnt/data --size 5G

# Debug mode to see all commands
./disk_management.sh -d resize --mount-point /mnt/data --size 5G
```

## Size Calculation

The command automatically calculates the minimum required size:

- **Minimum Size** = (Total file size) × 1.30 (adds 30% overhead)
- If `--size` is smaller than minimum, the minimum is used instead
- Size units supported: K/KB, M/MB, G/GB, T/TB

## Safety Features

1. **File Count Verification**: Ensures the same number of files are copied
2. **Size Verification**: Compares total data size (allows minor differences for filesystem metadata)
3. **Backup Creation**: Original VHD is renamed with `_bkp` suffix, not deleted
4. **Atomic Operation**: If any step fails, cleanup is performed (new VHD is removed)
5. **Mount Point Validation**: Verifies target mount point exists and has a mounted disk

## Backup Management

After a successful resize operation:

- **Original VHD**: Renamed to `<name>_bkp.vhdx` (e.g., `disk_bkp.vhdx`)
- **Location**: Same directory as original VHD
- **Cleanup**: You can delete the backup once you verify the resized disk works correctly

To delete the backup:

```bash
# Find the backup file
ls -lh /mnt/c/aNOS/VMs/wsl_test/*_bkp.vhdx

# Delete using the delete command
./disk_management.sh delete --path C:/aNOS/VMs/wsl_test/disk_bkp.vhdx --force
```

## Dependencies

The resize command requires:

- `rsync` - For file copying with attribute preservation
- `find` - For file counting
- `du` - For directory size calculation

## Error Handling

The command will fail and exit if:

- Mount point doesn't exist or has no mounted VHD
- Failed to create new VHD
- Failed to mount new VHD
- File copy fails
- File count mismatch after copy
- Failed to unmount/detach disks
- Failed to rename VHD files

In case of errors during file migration, the new VHD is cleaned up and the original disk remains intact.

## Output

### Normal Mode

Shows detailed progress including:
- Target disk detection
- Size calculations
- VHD creation progress
- File copy status
- Verification results
- Final disk information
- Backup location

### Quiet Mode (`-q`)

Outputs single line result:
```
C:/path/disk.vhdx: resized to 10G with UUID=<uuid>
```

### Debug Mode (`-d`)

Shows all executed commands before running them:
```
[DEBUG] find '/mnt/data' -type f | wc -l
[DEBUG] du -sb '/mnt/data' | awk '{print $1}'
[DEBUG] sudo rsync -a '/mnt/data/' '/mnt/data_temp/'
...
```

## Performance

Resize time depends on:
- **Data Size**: Larger data takes longer to copy
- **File Count**: More files increase overhead
- **Disk Speed**: Faster disks reduce copy time
- **Filesystem**: Some filesystems are faster than others

Example timings (approximate):
- 1GB with 1000 files: ~30 seconds
- 10GB with 10000 files: ~5 minutes
- 100GB with 100000 files: ~30-60 minutes

## Tips

1. **Check Disk Usage First**: Use `status --mount-point` to see current usage
2. **Plan for Growth**: Add extra space beyond current usage (30% minimum)
3. **Test with Small Disks**: Practice on small test disks first
4. **Verify Before Cleanup**: Check the resized disk thoroughly before deleting backup
5. **Use Debug Mode**: If issues occur, re-run with `-d` to see what's happening
6. **Monitor Space**: Ensure the Windows filesystem has enough space for both disks during migration
