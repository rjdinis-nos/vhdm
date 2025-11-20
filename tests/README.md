# WSL VHD Disk Management - Test Suite

This directory contains the test suite for validating the WSL VHD disk management scripts.

## Test Scripts

### `test_all.sh`
A comprehensive test runner that executes all test suites in sequence and reports overall results.

**Usage:**
```bash
./test_all.sh              # Run all tests
./test_all.sh -v           # Run all tests with verbose output
./test_all.sh -s           # Stop on first failure
./test_all.sh -v -s        # Verbose mode and stop on failure
```

**Features:**
- Runs all test suites in sequence
- Color-coded output with suite-level results
- Overall summary with pass/fail counts
- Optional verbose mode for detailed output
- Optional stop-on-failure mode for CI/CD

### `test_report.md`
An automatically generated test report that tracks test execution results over time.

**Features:**
- Summary table showing the latest status of all test suites
- Includes test run date, pass/fail status, test counts, and duration
- Maintains a chronological history of all test runs
- Updated automatically when test suites are executed

**View the report:**
```bash
cat tests/test_report.md
# Or open in any markdown viewer
```

### `update_test_report.sh`
Script that updates the test report with results from test suite executions. This script is called automatically by individual test scripts and generally doesn't need to be run manually.

**Usage (if needed manually):**
```bash
./update_test_report.sh --suite test_status.sh --status PASSED \
  --run 10 --passed 10 --failed 0 --duration 5
```

---

### `test_status.sh`
A comprehensive test suite for validating the status command functionality, including UUID lookup, path validation, and error handling scenarios.

**Coverage**: 10 tests covering status display, UUID/path/mount-point lookup, quiet mode, and error handling.

### `test_attach.sh`
Tests for the attach command, validating VHD attachment to WSL without filesystem mounting.

**Coverage**: 15 tests covering basic attach, idempotency, custom names, UUID detection, device reporting, quiet/debug modes, error handling, and various path formats.

**Features tested:**
- Basic attach with --path option
- Idempotency (attaching already-attached VHDs)
- Custom --name parameter
- Status verification after attach
- VHD not mounted after attach (block device only)
- Quiet mode machine-readable output
- Debug mode command visibility
- Error handling for non-existent paths
- Error handling for missing required parameters
- Detach and re-attach workflows
- UUID automatic detection and reporting
- Device name identification (/dev/sdX)
- Completion message display
- Combined quiet + debug mode
- Windows path with backslashes

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
Tests for the delete command, validating VHD file deletion with safety checks.

**Coverage**: 10 tests covering basic deletion, force mode, error handling, and cleanup verification.

### `test_resize.sh`
Tests for the resize command, validating VHD resizing through data migration including size calculations, file integrity, and backup creation.

**Coverage**: 21 tests covering parameter validation, helper functions, actual resize operations, size calculations, data integrity verification, backup creation, and multiple resize scenarios.

**Features tested:**
- Parameter validation (mount-point, size requirements)
- Helper functions (get_directory_size_bytes, convert_size_to_bytes, bytes_to_human)
- Actual resize operations with data migration (100M→200M)
- File integrity verification (file count, sample data)
- Backup creation (original VHD preserved with _bkp suffix)
- Multiple resize operations (successive resizing)
- Output modes (quiet, debug)
- Post-resize operations (unmount, remount)

---

## Running Tests

```bash
# Run all test suites at once
./tests/test_all.sh          # All tests in sequence
./tests/test_all.sh -v       # All tests with verbose output
./tests/test_all.sh -s       # Stop on first failure

# Run individual test suites
./tests/test_status.sh        # Status command tests
./tests/test_attach.sh        # Attach command tests
./tests/test_mount.sh         # Mount command tests
./tests/test_umount.sh        # Umount command tests
./tests/test_create.sh        # Create command tests
./tests/test_delete.sh        # Delete command tests
./tests/test_resize.sh        # Resize command tests

# Run with verbose output
./tests/test_status.sh -v
./tests/test_create.sh --verbose

# Run specific tests
./tests/test_status.sh -t 1        # Run test 1 only
./tests/test_create.sh -t 1 -t 3   # Run tests 1 and 3
./tests/test_status.sh -v -t 2     # Run test 2 with verbose output

# View test report
cat ./tests/test_report.md   # View the automatically generated test report
```

**Note:** Test results are automatically recorded to `tests/test_report.md` after each test run, including the date, pass/fail status, test counts, and execution duration.

---

## Test Coverage

### test_status.sh (10 tests)
1. **Default Status** - Validates status output with default configuration (shows usage/help)
2. **Status by UUID** - Tests UUID-based status lookup
3. **Status by Path** - Tests path-based status lookup (expects error when VHD not attached)
4. **Status by Mount Point** - Tests mount point-based status lookup
5. **Attached but Not Mounted** - Verifies detection of attached-but-unmounted state (sets up state first)
6. **Show All VHDs** - Tests `--all` flag functionality
7. **Quiet Mode** - Validates machine-readable output format
8. **Non-existent Path** - Tests error handling for invalid VHD paths
9. **Non-existent Mount Point** - Tests error handling for invalid mount points
10. **Non-existent UUID** - Tests error handling for invalid UUIDs

### test_attach.sh (15 tests)
1. **Attach with --path** - Tests basic attach operation with path parameter
2. **Attach idempotency** - Verifies attaching already-attached VHD succeeds gracefully
3. **Attach with custom --name** - Tests custom VHD name parameter
4. **Verify in status** - Confirms attached VHD appears in status output
5. **Not mounted after attach** - Verifies VHD is NOT mounted to filesystem (block device only)
6. **Quiet mode** - Tests machine-readable output format
7. **Debug mode** - Verifies debug mode shows all commands before execution
8. **Non-existent path** - Tests error handling for invalid VHD file paths
9. **Missing --path parameter** - Verifies error when required parameter is missing
10. **Detach and re-attach** - Tests full detach/attach cycle
11. **UUID detection** - Confirms UUID is automatically detected and reported
12. **Device name reported** - Verifies device name (/dev/sdX) is identified and displayed
13. **Completion message** - Tests completion message display
14. **Combined quiet + debug** - Tests both flags working together
15. **Windows backslash paths** - Tests Windows path format with backslashes

### test_create.sh (10 tests)
1. **Create with defaults** - Creates VHD with default 1G size and ext4 filesystem
2. **Verify file exists** - Confirms VHD file was created on disk
3. **Verify attached** - Confirms VHD is attached to WSL after creation
4. **Custom size** - Creates VHD with custom size (500M)
5. **Custom filesystem** - Creates VHD with xfs filesystem (falls back to ext4 if xfs tools not installed)
6. **Quiet mode** - Tests machine-readable output format
7. **Duplicate detection** - Attempts to create existing VHD (should fail)
8. **All custom params** - Creates VHD with all parameters specified
9. **Verify custom VHD** - Confirms custom VHD exists
10. **Verify filesystem** - Confirms VHD has proper filesystem with UUID

### test_mount.sh (10 tests)
1. **Mount with default config** - Tests basic mount operation
2. **Mount idempotency** - Verifies mounting already-mounted VHD succeeds
3. **Mount with explicit path** - Tests mount with path parameter
4. **Mount with custom mount point** - Tests custom mount point creation and usage
5. **Mount non-existent VHD** - Verifies error handling for missing files
6. **Mount creates directory** - Confirms mount point directory is created if needed
7. **Quiet mode** - Tests minimal output mode
8. **Mount point accessible** - Verifies mount point is accessible after mounting
9. **Filesystem mounted** - Confirms filesystem is properly mounted (checks mount point existence)
10. **Status shows mounted** - Verifies status command reflects mounted state

### test_umount.sh (10 tests)
Tests unmount operations including cleanup verification and multiple unmount methods:
1. **Umount with default config** - Tests basic unmount operation
2. **Umount idempotency** - Verifies unmounting already-unmounted VHD succeeds
3. **Umount with UUID** - Tests unmount by UUID parameter
4. **Umount with path** - Tests unmount by path parameter
5. **Umount with mount point** - Tests unmount by mount point parameter
6. **Mount point not accessible** - Confirms mount point is unmounted after operation
7. **Quiet mode** - Tests minimal output mode
8. **VHD detached** - Verifies VHD is detached from WSL after unmount
9. **Status shows not mounted** - Confirms status reflects unmounted state
10. **Non-existent UUID handling** - Tests graceful handling of invalid UUIDs

### test_delete.sh (10 tests)
Tests for the delete command, validating VHD deletion with proper state checking:
1. **Delete attached VHD fails** - Verifies error when attempting to delete attached VHD
2. **Delete detached VHD** - Tests successful deletion of detached VHD
3. **Verify file removed** - Confirms VHD file is deleted from disk
4. **Delete with --force flag** - Tests force deletion without prompts
5. **Delete in quiet mode** - Tests minimal output mode
6. **Delete non-existent VHD** - Verifies error handling for missing files
7. **Delete without path parameter** - Tests error handling for missing required parameter
8. **Create and delete** - Tests full lifecycle (create, detach, delete)
9. **Verify deletion** - Confirms temp VHD is removed
10. **Delete already deleted** - Tests error handling for double deletion

### test_resize.sh (21 tests)
Comprehensive tests for the resize command, validating VHD resizing through data migration:
1. **Missing mount-point parameter** - Verifies error when --mount-point not provided
2. **Missing size parameter** - Verifies error when --size not provided
3. **Non-existent mount point** - Tests error handling for invalid mount points
4. **Unmounted disk** - Verifies error when attempting to resize unmounted VHD
5. **Test VHD creation** - Creates 100M test VHD with 10MB sample data
6. **Directory size calculation** - Tests get_directory_size_bytes() helper function
7. **Size conversion (5G)** - Tests convert_size_to_bytes() with gigabytes
8. **Size conversion (100M)** - Tests convert_size_to_bytes() with megabytes
9. **Bytes to human** - Tests bytes_to_human() conversion function
10. **Resize to larger size** - Performs actual resize operation from 100M to 200M
11. **Disk mounted after resize** - Verifies disk remains mounted after operation
12. **File count matches** - Confirms all files copied during migration
13. **Data integrity** - Verifies sample files exist and are accessible
14. **Backup VHD created** - Confirms original VHD backed up with _bkp suffix
15. **Status shows new UUID** - Verifies disk has new UUID after resize
16. **Automatic size calculation** - Tests minimum size calculation (data + 30%)
17. **Disk functional after second resize** - Confirms disk works after multiple resizes
18. **Quiet mode output** - Tests machine-readable output format
19. **Debug mode** - Verifies debug mode shows [DEBUG] command output
20. **Unmount resized disk** - Tests unmount still works after resize
21. **Re-mount resized disk** - Tests mount still works after resize

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

**Resize Tests**: The resize test suite creates its own temporary VHD (`resize_test.vhdx`) to avoid interfering with the main test VHD. This temporary VHD is automatically cleaned up after tests complete.

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

### Output Suppression
All test commands suppress non-test output to keep results clean:

```bash
# For commands that need output validation (grep)
run_test "Test" "bash $PARENT_DIR/disk_management.sh command 2>&1 | grep -q 'pattern'" 0

# For setup/cleanup operations (full suppression)
cleanup_test_vhd "${TEST_VHD_BASE}_1.vhdx" >/dev/null 2>&1
```

This ensures only test framework output (test names, PASSED/FAILED status) is displayed.

### Exit Code Expectations
- Status queries return `0` when displaying information, `1` when VHD not found or error occurs
- Status with `--path` returns `1` if VHD exists but is not attached (with helpful suggestions)
- Grep-based tests return `0` when pattern matches, `1` when it doesn't
- Mount/umount operations are idempotent: return `0` even if already in desired state
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
run_test "Test name" "command 2>&1 | grep -q 'expected pattern'" 0
```

3. Suppress non-test output:
   - For commands: redirect stderr to stdout with `2>&1`
   - For setup/cleanup: use `>/dev/null 2>&1`

4. Handle optional dependencies:
```bash
if ! which mkfs.xfs >/dev/null 2>&1; then
    # Adjust test or skip
fi
```

5. Increment test numbering sequentially

6. Test both success and error scenarios

7. Verify exit codes match actual command behavior

8. Add verbose output details if needed

---

## Test Maintenance

### Before Running Tests
- Ensure `.env.test` is properly configured
- Verify VHD file exists at the specified path
- Confirm VHD UUID matches the configuration
- Check mount point is correctly set

### Test State Management
Some tests require specific VHD states:
- **Attached but not mounted**: Test 5 in test_status.sh mounts then unmounts filesystem (keeping VHD attached)
- **Detached state**: Tests ensure cleanup by fully detaching VHDs after testing
- **Setup/teardown**: Tests use setup functions to establish required states before assertions

### When Tests Fail
1. Run in verbose mode to see detailed output: `./tests/test_status.sh -v`
2. Check VHD state (attached vs mounted vs detached)
3. Verify `.env.test` configuration matches actual VHD
4. Review test expectations match current implementation
5. Check if test setup properly establishes required state

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
- **Fast execution** - all tests complete in under a minute
- **Comprehensive runner** - `test_all.sh` runs all suites with overall status

### CI Example
```bash
#!/bin/bash
cd /path/to/scripts

# Run all tests
./tests/test_all.sh
if [ $? -eq 0 ]; then
    echo "All tests passed"
    exit 0
else
    echo "Tests failed"
    exit 1
fi

# Or stop on first failure
./tests/test_all.sh --stop-on-failure
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

## Test Reporting

All test suites automatically update the `test_report.md` file with their results. The report includes:

- **Last Updated**: Timestamp of the most recent test run
- **Test Suite Summary Table**: Shows latest run date, status, counts, and duration for each suite
- **Test History**: Chronological log of all test executions with detailed results

The report is useful for:
- Tracking test trends over time
- Identifying frequently failing tests
- Monitoring test execution performance
- Quick overview of test suite health

## Future Enhancements

Potential areas for test expansion:

- [x] Mount operation tests - `test_mount.sh`
- [x] Unmount operation tests - `test_umount.sh`
- [x] Create operation tests - `test_create.sh`
- [x] Automated test reporting - `test_report.md`
- [ ] Delete operation tests - `test_delete.sh` (waiting for delete command implementation)
- [ ] Error recovery tests
- [ ] Performance benchmarks
- [ ] Integration tests with multiple VHDs
- [ ] Concurrent operation tests
- [ ] Edge case validation (special characters in paths, etc.)
- [ ] Test coverage reporting
- [ ] CI/CD pipeline integration
