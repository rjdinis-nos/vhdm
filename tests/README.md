# WSL VHD Disk Management - Test Suite

This directory contains the test suite for validating the WSL VHD disk management scripts.

## Test Scripts

### `test_status.sh`
A comprehensive test suite for validating the status command functionality, including UUID lookup, path validation, and error handling scenarios.

**Coverage**: 10 tests covering status display, UUID/path/mount-point lookup, quiet mode, and error handling.

### `test_mount.sh`
Tests for the mount command, validating VHD attachment and filesystem mounting operations.

**Coverage**: Tests mount by path, UUID, and mount point, including idempotency checks.

### `test_umount.sh`
Tests for the umount command, validating VHD detachment and filesystem unmounting operations.

**Coverage**: Tests unmount by path, UUID, and mount point, including cleanup verification.

### `test_create.sh`
Tests for the create command, validating VHD creation with various parameters.

**Coverage**: 10 tests covering default creation, custom sizes, filesystems, quiet mode, duplicate detection, and cleanup.

### `test_delete.sh`
Placeholder tests for the delete command (not yet implemented in disk_management.sh).

**Coverage**: 10 placeholder tests ready for when delete functionality is added.

---

## Running Tests

```bash
# Run individual test suites
./tests/test_status.sh        # Status command tests
./tests/test_mount.sh         # Mount command tests
./tests/test_umount.sh        # Umount command tests
./tests/test_create.sh        # Create command tests
./tests/test_delete.sh        # Delete command tests (placeholder)

# Run with verbose output
./tests/test_status.sh -v
./tests/test_create.sh --verbose

# Run specific tests
./tests/test_status.sh -t 1        # Run test 1 only
./tests/test_create.sh -t 1 -t 3   # Run tests 1 and 3
./tests/test_status.sh -v -t 2     # Run test 2 with verbose output

# Run all test suites
for test in ./tests/test_*.sh; do
    echo "Running $test..."
    $test || exit 1
done
```

---

## Test Coverage

### test_status.sh (10 tests)
1. **Default Status** - Validates status output with default configuration
2. **Status by UUID** - Tests UUID-based status lookup
3. **Status by Path** - Tests path-based status lookup
4. **Status by Mount Point** - Tests mount point-based status lookup
5. **Attached but Not Mounted** - Verifies detection of attached-but-unmounted state
6. **Show All VHDs** - Tests `--all` flag functionality
7. **Quiet Mode** - Validates machine-readable output format
8. **Non-existent Path** - Tests error handling for invalid VHD paths
9. **Non-existent Mount Point** - Tests error handling for invalid mount points
10. **Non-existent UUID** - Tests error handling for invalid UUIDs

### test_create.sh (10 tests)
1. **Create with defaults** - Creates VHD with default 1G size and ext4 filesystem
2. **Verify file exists** - Confirms VHD file was created on disk
3. **Verify attached** - Confirms VHD is attached to WSL after creation
4. **Custom size** - Creates VHD with custom size (500M)
5. **Custom filesystem** - Creates VHD with xfs filesystem
6. **Quiet mode** - Tests machine-readable output format
7. **Duplicate detection** - Attempts to create existing VHD (should fail)
8. **All custom params** - Creates VHD with all parameters specified
9. **Verify custom VHD** - Confirms custom VHD exists
10. **Verify filesystem** - Confirms VHD has proper filesystem with UUID

### test_mount.sh
Tests mount operations including idempotency, path/UUID/mount-point variants, and error handling.

### test_umount.sh
Tests unmount operations including cleanup verification and multiple unmount methods.

### test_delete.sh (10 placeholder tests)
Tests prepared for future delete command implementation. Currently all tests are skipped with helpful implementation guidance.

---

## Test Configuration

Tests use the `.env.test` configuration file located in the `tests/` directory. Ensure this file exists with valid settings:

```bash
WSL_DISKS_DIR="C:/aNOS/VMs/wsl_test/"
VHD_PATH="${WSL_DISKS_DIR}disk.vhdx"
VHD_UUID="3e76fe9e-c345-4097-b8e2-aa3936ab83bc"  # Used for explicit test validation
MOUNT_POINT="/home/$USER/disk"
VHD_NAME="disk"
```

**Note**: While the main scripts use automatic UUID discovery, tests explicitly use `VHD_UUID` for validation scenarios to ensure correct behavior.

---

## Test Output Examples

### Concise Mode (default)
```
[PASS] Test 1: Default status shows VHD info
[PASS] Test 2: Status by UUID
[PASS] Test 3: Status by path
[PASS] Test 4: Status by mount point
[PASS] Test 5: Status shows attached but not mounted
[PASS] Test 6: Show all VHDs
[PASS] Test 7: Quiet mode output
[PASS] Test 8: Non-existent path error handling
[PASS] Test 9: Non-existent mount point error handling
[PASS] Test 10: Non-existent UUID error handling

Tests run: 10, Tests passed: 10, Tests failed: 0
All tests passed! ✓
```

### Verbose Mode
```
Running Test 1: Default status shows VHD info
  Command: bash /home/user/scripts/disk_management.sh status
  Expected exit code: 0
  Actual exit code: 0
[PASS] Test 1: Default status shows VHD info

Running Test 2: Status by UUID
  Command: bash /home/user/scripts/disk_management.sh status --uuid 3e76fe9e-c345-4097-b8e2-aa3936ab83bc
  Expected exit code: 0
  Actual exit code: 0
[PASS] Test 2: Status by UUID

...
```

---

## Test Implementation Details

### Test Pattern
Tests follow a consistent pattern using the `run_test` function:

```bash
run_test "Description" "command" expected_exit_code
```

For output validation using grep:
```bash
run_test "Description" "command | grep -q 'pattern'" 0
```

### Exit Code Expectations
- Status queries return `0` on successful information display (even if VHD not found)
- Grep-based tests return `0` when pattern matches, `1` when it doesn't
- File/mount point validation failures provide suggestions and return appropriate codes

### Color-Coded Output
- **Green** `[PASS]` - Test passed
- **Red** `[FAIL]` - Test failed
- **Cyan** - Test details in verbose mode
- **Yellow** - Summary statistics

---

## Adding New Tests

To add a new test to the suite:

1. Add a test function call following the pattern:
```bash
run_test "Test description" "command to execute" expected_exit_code
```

2. For output validation, use grep patterns:
```bash
run_test "Test name" "command | grep -q 'expected pattern'" 0
```

3. Increment test numbering sequentially

4. Test both success and error scenarios

5. Verify exit codes match actual command behavior

6. Add verbose output details if needed

---

## Test Maintenance

### Before Running Tests
- Ensure `.env.test` is properly configured
- Verify VHD file exists at the specified path
- Confirm VHD UUID matches the configuration
- Check mount point is correctly set

### When Tests Fail
1. Run in verbose mode to see detailed output: `./tests/test_status.sh -v`
2. Check VHD state (attached vs mounted vs detached)
3. Verify `.env.test` configuration matches actual VHD
4. Review test expectations match current implementation

### Updating Tests
- Test expectations must match actual VHD state (mounted vs unmounted)
- Update `.env.test` if creating new test VHDs
- Verbose mode aids debugging without modifying test logic
- Ensure color codes work in your terminal environment

---

## Continuous Integration

The test suite is designed to work in CI/CD environments:

- **Concise mode** (default) produces clean, one-line-per-test output
- **Exit codes** properly indicate success (0) or failure (non-zero)
- **No user interaction** required
- **Fast execution** - all 10 tests complete in seconds

### CI Example
```bash
#!/bin/bash
cd /path/to/scripts
./tests/test_status.sh
if [ $? -eq 0 ]; then
    echo "All tests passed"
    exit 0
else
    echo "Tests failed"
    exit 1
fi
```

---

## Troubleshooting

### Test fails with "VHD file not found"
- Check that VHD path in `.env.test` is correct
- Verify VHD file exists: `ls -la $(wslpath "C:/aNOS/VMs/wsl_test/disk.vhdx")`

### Test fails with "UUID not found"
- VHD may not be attached to WSL
- UUID in `.env.test` may be outdated (changes when reformatted)
- Run: `sudo blkid` to see all UUIDs

### Test fails with "Mount point not found"
- VHD may be attached but not mounted
- Check: `df -h | grep disk` or `mount | grep disk`
- Mount manually: `sudo mount UUID=<uuid> /home/$USER/disk`

### All tests fail
- Ensure scripts are executable: `chmod +x ../disk_management.sh tests/test_status.sh`
- Check that `wsl_helpers.sh` is in the parent libs directory
- Verify `.env.test` exists in the tests directory

---

## Future Enhancements

Potential areas for test expansion:

- [x] Mount operation tests - `test_mount.sh`
- [x] Unmount operation tests - `test_umount.sh`
- [x] Create operation tests - `test_create.sh`
- [ ] Delete operation tests - `test_delete.sh` (waiting for delete command implementation)
- [ ] Error recovery tests
- [ ] Performance benchmarks
- [ ] Integration tests with multiple VHDs
- [ ] Concurrent operation tests
- [ ] Edge case validation (special characters in paths, etc.)
- [ ] Automated test runner script
- [ ] Test coverage reporting
- [ ] CI/CD pipeline integration
