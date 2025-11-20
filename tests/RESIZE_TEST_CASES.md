# Resize Command Test Cases

## Overview

The `test_resize.sh` script provides comprehensive testing for the VHD resize functionality. It validates parameter handling, helper functions, data migration, integrity checks, and edge cases.

## Test Configuration

- **Test VHD**: `resize_test.vhdx` (created temporarily)
- **Initial Size**: 100M
- **Sample Data**: ~10MB (10 × 1MB files plus small config files)
- **Test Mount Point**: `/home/$USER/resize_test`
- **Cleanup**: Automatic cleanup after all tests complete

## Complete Test Case List (21 Tests)

### Parameter Validation Tests (1-4)

#### Test 1: Missing mount-point parameter
- **Purpose**: Verify error when --mount-point not provided
- **Command**: `resize --size 200M`
- **Expected**: Error message "mount-point is required"
- **Exit Code**: 1

#### Test 2: Missing size parameter
- **Purpose**: Verify error when --size not provided
- **Command**: `resize --mount-point /tmp/test`
- **Expected**: Error message "size is required"
- **Exit Code**: 1

#### Test 3: Non-existent mount point
- **Purpose**: Test error handling for invalid mount points
- **Command**: `resize --mount-point /nonexistent/path --size 200M`
- **Expected**: Error message "does not exist"
- **Exit Code**: 1

#### Test 4: Unmounted disk
- **Purpose**: Verify error when attempting to resize unmounted VHD
- **Setup**: Create mount point directory without mounting VHD
- **Command**: `resize --mount-point /tmp/test_unmounted_resize --size 200M`
- **Expected**: Error message "No VHD mounted"
- **Exit Code**: 1

---

### Test VHD Setup (5)

#### Test 5: Test VHD creation with data
- **Purpose**: Create test environment for resize operations
- **Actions**:
  - Create 100M VHD with ext4 filesystem
  - Mount at test mount point
  - Create sample data structure:
    - `/data` directory with 10 × 1MB files
    - `/config` directory with small config file
    - `/logs` directory with small log file
- **Expected**: VHD created, mounted, and populated with data
- **Validation**: Mount point exists and contains data directories

---

### Helper Function Tests (6-9)

#### Test 6: Directory size calculation
- **Purpose**: Validate get_directory_size_bytes() function
- **Test**: Calculate size of test mount point
- **Expected**: Returns numeric value (bytes)
- **Validation**: Output matches regex `^[0-9]+$`

#### Test 7: Size conversion (5G)
- **Purpose**: Test convert_size_to_bytes() with gigabytes
- **Input**: "5G"
- **Expected**: 5368709120 bytes
- **Validation**: Exact match

#### Test 8: Size conversion (100M)
- **Purpose**: Test convert_size_to_bytes() with megabytes
- **Input**: "100M"
- **Expected**: 104857600 bytes
- **Validation**: Exact match

#### Test 9: Bytes to human conversion
- **Purpose**: Test bytes_to_human() formatting
- **Input**: 5368709120 bytes
- **Expected**: "5.00GB"
- **Validation**: Pattern match `5\.00GB`

---

### Primary Resize Operation (10-15)

#### Test 10: Resize to larger size (200M)
- **Purpose**: Perform actual resize operation
- **Pre-State**: 100M VHD with ~10MB data
- **Command**: `resize --mount-point <test_mount> --size 200M`
- **Expected**: 
  - New VHD created with 200M size
  - All files copied successfully
  - Verification passes
  - Original backed up as `resize_test_bkp.vhdx`
  - New VHD mounted at original location
- **Duration**: ~30-60 seconds
- **Exit Code**: 0

#### Test 11: Disk mounted after resize
- **Purpose**: Verify disk remains accessible after resize
- **Validation**: `mountpoint -q` returns true
- **Expected**: Mount point is active filesystem
- **Exit Code**: 0

#### Test 12: File count matches
- **Purpose**: Ensure all files were copied during migration
- **Method**: Compare file count before and after resize
- **Expected**: Counts are identical
- **Validation**: `find` command returns same number

#### Test 13: Data integrity
- **Purpose**: Verify sample files exist and are accessible
- **Checks**:
  - `/data/file_1.dat` exists
  - `/config/test.conf` exists
- **Expected**: Both files present and readable
- **Exit Code**: 0

#### Test 14: Backup VHD created
- **Purpose**: Confirm original VHD was backed up
- **Check**: File exists at `resize_test_bkp.vhdx`
- **Expected**: Backup file present on disk
- **Exit Code**: 0

#### Test 15: Status shows new UUID
- **Purpose**: Verify disk has new UUID after resize
- **Command**: `status --mount-point <test_mount>`
- **Expected**: Output contains "UUID:" field
- **Note**: UUID changes because new VHD was formatted
- **Exit Code**: 0

---

### Edge Cases and Additional Operations (16-19)

#### Test 16: Automatic size calculation
- **Purpose**: Test minimum size calculation (data + 30%)
- **Scenario**: Request size smaller than required minimum
- **Command**: `resize --mount-point <test_mount> --size 10M`
- **Current Data**: ~10MB
- **Minimum Required**: ~13MB (10MB + 30%)
- **Expected**: 
  - Warning message about size being too small
  - Uses minimum required size instead
  - Operation completes successfully
- **Validation**: Output contains "Requested size" or "smaller than required" or "Using minimum"

#### Test 17: Disk functional after second resize
- **Purpose**: Confirm disk works after multiple resize operations
- **Validation**: 
  - `/data` directory still exists
  - `file_1.dat` still present
- **Expected**: Data integrity maintained after second resize
- **Exit Code**: 0

#### Test 18: Quiet mode output
- **Purpose**: Test machine-readable output format
- **Command**: `resize -q --mount-point <test_mount> --size 250M`
- **Expected**: Output matches pattern `resized to .* with UUID=`
- **Format**: `<path>: resized to <size> with UUID=<uuid>`
- **Exit Code**: 0

#### Test 19: Debug mode shows commands
- **Purpose**: Verify debug mode outputs [DEBUG] markers
- **Command**: `resize -d --mount-point <test_mount> --size 300M`
- **Expected**: Output contains "[DEBUG]" strings
- **Validation**: Commands shown before execution
- **Exit Code**: 0

---

### Post-Resize Operations (20-21)

#### Test 20: Unmount resized disk
- **Purpose**: Test unmount still works after resize
- **Command**: `umount -q --mount-point <test_mount>`
- **Expected**: Disk unmounts cleanly
- **Validation**: No errors, clean detachment
- **Exit Code**: 0

#### Test 21: Re-mount resized disk
- **Purpose**: Test mount still works after resize
- **Command**: `mount -q --path <test_path> --mount-point <test_mount>`
- **Expected**: Disk mounts successfully
- **Validation**: Mount operation succeeds
- **Exit Code**: 0

---

## Test Execution

### Run All Tests
```bash
./tests/test_resize.sh
```

### Run Specific Tests
```bash
# Run only parameter validation tests
./tests/test_resize.sh -t 1 -t 2 -t 3 -t 4

# Run only helper function tests
./tests/test_resize.sh -t 6 -t 7 -t 8 -t 9

# Run actual resize operation only
./tests/test_resize.sh -t 10

# Run with verbose output
./tests/test_resize.sh -v
```

### Expected Output (Summary)
```
========================================
  Disk Management Resize Tests
========================================
Running tests... (use -v for detailed output)

Test 1: Missing mount-point parameter                              ✓ PASSED
Test 2: Missing size parameter                                     ✓ PASSED
Test 3: Non-existent mount point                                   ✓ PASSED
Test 4: Unmounted disk                                             ✓ PASSED
Test 5: Test VHD created successfully with data                    ✓ PASSED
Test 6: Directory size calculation works                           ✓ PASSED
Test 7: Size conversion to bytes works (5G)                        ✓ PASSED
Test 8: Size conversion to bytes works (100M)                      ✓ PASSED
Test 9: Bytes to human conversion works                            ✓ PASSED
Test 10: Resize to larger size (200M) completes successfully       ✓ PASSED
Test 11: Disk is mounted after resize                              ✓ PASSED
Test 12: File count matches after resize (13 files)                ✓ PASSED
Test 13: Sample data files exist after resize                      ✓ PASSED
Test 14: Backup VHD was created                                    ✓ PASSED
Test 15: Status shows resized disk info                            ✓ PASSED
Test 16: Resize with too-small size uses minimum (data + 30%)     ✓ PASSED
Test 17: Disk is functional after second resize                    ✓ PASSED
Test 18: Quiet mode resize outputs parseable result                ✓ PASSED
Test 19: Debug mode shows executed commands                        ✓ PASSED
Test 20: Unmount resized disk works                                ✓ PASSED
Test 21: Re-mount resized disk works                               ✓ PASSED

========================================
  Test Summary
========================================
Tests run:    21
Tests passed: 21
Tests failed: 0
Duration:     120s
========================================
```

## Test Coverage Analysis

### Functional Coverage
- ✅ Parameter validation (4 tests)
- ✅ Helper function correctness (4 tests)
- ✅ Primary resize operation (6 tests)
- ✅ Edge cases and automation (4 tests)
- ✅ Post-operation functionality (2 tests)
- ✅ Output modes (quiet, debug) (2 tests)

### Error Handling Coverage
- ✅ Missing required parameters
- ✅ Invalid mount points
- ✅ Unmounted disks
- ✅ Size calculation edge cases

### Data Integrity Coverage
- ✅ File count verification
- ✅ File existence checks
- ✅ Multiple resize operations
- ✅ Backup creation

### Integration Coverage
- ✅ Mount/unmount after resize
- ✅ Status command integration
- ✅ Quiet mode integration
- ✅ Debug mode integration

## Performance Considerations

- **Test Duration**: ~2-3 minutes for all tests
- **Disk Space**: Requires ~500MB temporarily (test VHDs + backups)
- **Network**: No network required
- **Dependencies**: bc, rsync, qemu-img, jq

## Cleanup

All test resources are automatically cleaned up:
- Test VHD deleted
- Backup VHD deleted
- Mount points removed
- Temporary directories removed

Manual cleanup (if needed):
```bash
# Remove test VHD and backups
rm -f /mnt/c/aNOS/VMs/wsl_test/resize_test*.vhdx

# Remove mount points
sudo rm -rf /home/$USER/resize_test*
```

## Known Limitations

1. **Filesystem metadata**: Size comparison allows minor differences due to filesystem overhead
2. **Timing sensitive**: Sleep delays may need adjustment on slower systems
3. **WSL-specific**: Tests require WSL 2 environment
4. **Sudo required**: Tests need sudo access for mount/umount operations

## Future Enhancements

- Test with different filesystems (xfs, btrfs)
- Test with larger data sets
- Test concurrent resize operations
- Test network-mounted VHDs
- Performance benchmarking tests
- Stress tests with many small files
