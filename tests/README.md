# WSL VHD Disk Management - Test Suite

This directory contains the test suite for validating the WSL VHD disk management scripts.

## Test Scripts

### `test_status.sh`
A comprehensive test suite for validating the status command functionality, including UUID lookup, path validation, and error handling scenarios.

---

## Running Tests

```bash
# Run all tests (concise output)
./tests/test_status.sh

# Run tests with verbose output
./tests/test_status.sh -v
./tests/test_status.sh --verbose
```

---

## Test Coverage

The test suite includes 10 comprehensive tests:

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

- [ ] Mount operation tests
- [ ] Unmount operation tests  
- [ ] Create operation tests
- [ ] Error recovery tests
- [ ] Performance benchmarks
- [ ] Integration tests with multiple VHDs
- [ ] Concurrent operation tests
- [ ] Edge case validation (special characters in paths, etc.)
