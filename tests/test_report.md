# WSL VHD Disk Management - Test Report

Last Updated: 2025-11-20 13:12:20

## Test Suite Summary

| Test Suite | Last Run | Status | Tests Run | Passed | Failed | Duration |
|------------|----------|--------|-----------|--------|--------|----------|
| test_status.sh | 2025-11-20 | ✗ FAILED | 10 | 9 | 1 | 6s |
| test_mount.sh | 2025-11-20 | ✓ PASSED | 10 | 10 | 0 | 30s |
| test_umount.sh | 2025-11-20 | ✗ FAILED | 10 | 2 | 8 | 6s |
| test_create.sh | 2025-11-20 | ✓ PASSED | 10 | 10 | 0 | 26s |
| test_delete.sh | 2025-11-20 | ✗ FAILED | 10 | 4 | 6 | 31s |

## Test History

### 2025-11-20 13:12:20 - test_delete.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 4
- **Tests Failed:** 6
- **Duration:** 31s

**Failed Tests:**
- Test 2: Delete detached VHD by path
- Test 3: Verify VHD file is removed after delete
- Test 4: Delete detached VHD with --force flag
- Test 5: Delete in quiet mode
- Test 8: Create, detach, and delete a VHD
- Test 9: Verify temp VHD is removed


### 2025-11-20 13:11:49 - test_create.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 26s


### 2025-11-20 13:11:23 - test_umount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 2
- **Tests Failed:** 8
- **Duration:** 6s

**Failed Tests:**
- Test 1: Umount mounted VHD with default configuration
- Test 2: Umount already-unmounted VHD (idempotency)
- Test 3: Umount with UUID parameter
- Test 4: Umount with path parameter
- Test 5: Umount with mount point parameter
- Test 6: Mount point not accessible after umount
- Test 8: VHD is detached from WSL after umount
- Test 9: Status shows VHD as not mounted after umount


### 2025-11-20 13:11:17 - test_mount.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 30s


### 2025-11-20 13:10:10 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 9
- **Tests Failed:** 1
- **Duration:** 6s

**Failed Tests:**
- Test 3: Status with specific path


### 2025-11-20 13:09:50 - test_delete.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 4
- **Tests Failed:** 6
- **Duration:** 50s

**Failed Tests:**
- Test 2: Delete detached VHD by path
- Test 3: Verify VHD file is removed after delete
- Test 4: Delete detached VHD with --force flag
- Test 5: Delete in quiet mode
- Test 8: Create, detach, and delete a VHD
- Test 9: Verify temp VHD is removed


### 2025-11-20 13:09:00 - test_create.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 35s


### 2025-11-20 13:08:25 - test_umount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 2
- **Tests Failed:** 8
- **Duration:** 6s

**Failed Tests:**
- Test 1: Umount mounted VHD with default configuration
- Test 2: Umount already-unmounted VHD (idempotency)
- Test 3: Umount with UUID parameter
- Test 4: Umount with path parameter
- Test 5: Umount with mount point parameter
- Test 6: Mount point not accessible after umount
- Test 8: VHD is detached from WSL after umount
- Test 9: Status shows VHD as not mounted after umount


### 2025-11-20 13:08:19 - test_mount.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 22s


### 2025-11-20 13:07:17 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 9
- **Tests Failed:** 1
- **Duration:** 4s

**Failed Tests:**
- Test 3: Status with specific path


### 2025-11-20 12:56:20 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 5
- **Tests Failed:** 5
- **Duration:** 14s

**Failed Tests:**
- Test 1: Detach VHD that is attached but not mounted
- Test 3: Detach already-detached VHD (idempotency)
- Test 4: VHD is detached from WSL after detach
- Test 5: Mount point not accessible after detach
- Test 10: Status shows VHD as not attached after detach


### 2025-11-20 12:46:39 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 36s

**Failed Tests:**
- Test 1: Detach VHD that is attached but not mounted


### 2025-11-20 12:45:43 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 4
- **Tests Failed:** 6
- **Duration:** 223s

**Failed Tests:**
- Test 1: Detach VHD that is attached but not mounted
- Test 2: Detach VHD that is attached and mounted
- Test 3: Detach already-detached VHD (idempotency)
- Test 4: VHD is detached from WSL after detach
- Test 5: Mount point not accessible after detach
- Test 10: Status shows VHD as not attached after detach


### 2025-11-20 12:41:03 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 4s

**Failed Tests:**
- Test 3: Detach already-detached VHD (idempotency)


### 2025-11-20 12:39:48 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 4
- **Tests Failed:** 6
- **Duration:** 133s

**Failed Tests:**
- Test 1: Detach VHD that is attached but not mounted
- Test 2: Detach VHD that is attached and mounted
- Test 3: Detach already-detached VHD (idempotency)
- Test 4: VHD is detached from WSL after detach
- Test 5: Mount point not accessible after detach
- Test 10: Status shows VHD as not attached after detach


### 2025-11-20 12:36:39 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 5s

**Failed Tests:**
- Test 1: Detach VHD that is attached but not mounted


### 2025-11-20 12:34:42 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 5s

**Failed Tests:**
- Test 1: Detach VHD that is attached but not mounted


### 2025-11-20 12:34:25 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 3
- **Tests Failed:** 7
- **Duration:** 18s

**Failed Tests:**
- Test 1: Detach VHD that is attached but not mounted
- Test 2: Detach VHD that is attached and mounted
- Test 3: Detach already-detached VHD (idempotency)
- Test 4: VHD is detached from WSL after detach
- Test 5: Mount point not accessible after detach
- Test 6: Detach in quiet mode produces minimal output
- Test 10: Status shows VHD as not attached after detach


### 2025-11-20 02:03:57 - test_mount.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 23s


### 2025-11-20 02:03:28 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 6s


### 2025-11-20 01:51:18 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 6s


### 2025-11-20 01:45:13 - test_delete.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 25s


### 2025-11-20 01:43:56 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 5s



---
*This report is automatically generated and updated when test suites are executed.*
