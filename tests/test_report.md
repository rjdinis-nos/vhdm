# WSL VHD Disk Management - Test Report

Last Updated: 2025-11-20 12:56:20

## Test Suite Summary

| Test Suite | Last Run | Status | Tests Run | Passed | Failed | Duration |
|------------|----------|--------|-----------|--------|--------|----------|
| test_status.sh | 2025-11-20 | ✓ PASSED | 10 | 10 | 0 | 6s |
| test_mount.sh | 2025-11-20 | ✓ PASSED | 10 | 10 | 0 | 23s |
| test_umount.sh | - | - | - | - | - | - |
| test_create.sh | - | - | - | - | - | - |
| test_delete.sh | 2025-11-20 | ✓ PASSED | 10 | 10 | 0 | 25s |

## Test History

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
