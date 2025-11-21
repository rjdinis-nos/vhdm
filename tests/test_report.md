# WSL VHD Disk Management - Test Report

Last Updated: 2025-11-21 01:16:57

## Test Suite Summary

| Test Suite | Last Run | Status | Tests Run | Passed | Failed | Duration |
|------------|----------|--------|-----------|--------|--------|----------|
| test_status.sh | 2025-11-21 | ✓ PASSED | 10 | 10 | 0 | 12s |
| test_mount.sh | 2025-11-21 | ✓ PASSED | 10 | 10 | 0 | 16s |
| test_umount.sh | 2025-11-21 | ✓ PASSED | 10 | 10 | 0 | 39s |
| test_create.sh | 2025-11-21 | ✓ PASSED | 10 | 10 | 0 | 7s |
| test_delete.sh | 2025-11-21 | ✓ PASSED | 10 | 10 | 0 | 3s |

## Test History

### 2025-11-21 01:16:57 - test_delete.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 3s


### 2025-11-21 01:16:54 - test_create.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 7s


### 2025-11-21 01:16:47 - test_umount.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 39s


### 2025-11-21 01:16:08 - test_mount.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 16s


### 2025-11-21 01:15:36 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 12s


### 2025-11-21 01:05:05 - test_delete.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 3s


### 2025-11-21 01:05:02 - test_create.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 7s


### 2025-11-21 01:04:55 - test_umount.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 39s


### 2025-11-21 01:04:15 - test_mount.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 17s


### 2025-11-21 01:03:36 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 13s


### 2025-11-21 01:02:32 - test_umount.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 38s


### 2025-11-21 01:01:31 - test_umount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 1
- **Duration:** 19s

**Failed Tests:**
- Test 2: Umount already-unmounted VHD (idempotency)


### 2025-11-21 01:00:47 - test_umount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 9
- **Tests Failed:** 1
- **Duration:** 40s

**Failed Tests:**
- Test 2: Umount already-unmounted VHD (idempotency)


### 2025-11-21 00:59:34 - test_umount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 6s

**Failed Tests:**
- Test 9: Status shows VHD as not mounted after umount


### 2025-11-21 00:59:14 - test_umount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 9s

**Failed Tests:**
- Test 8: VHD is detached from WSL after umount


### 2025-11-21 00:59:02 - test_umount.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 0
- **Duration:** 13s


### 2025-11-21 00:58:33 - test_umount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 34s

**Failed Tests:**
- Test 2: Umount already-unmounted VHD (idempotency)
- Test 8: VHD is detached from WSL after umount
- Test 9: Status shows VHD as not mounted after umount


### 2025-11-21 00:57:37 - test_umount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 2
- **Tests Failed:** 8
- **Duration:** 1s

**Failed Tests:**
- Test 1: Umount mounted VHD with default configuration
- Test 2: Umount already-unmounted VHD (idempotency)
- Test 3: Umount with UUID parameter
- Test 4: Umount with path parameter
- Test 5: Umount with mount point parameter
- Test 6: Mount point not accessible after umount
- Test 8: VHD is detached from WSL after umount
- Test 9: Status shows VHD as not mounted after umount


### 2025-11-21 00:57:03 - test_mount.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 15s


### 2025-11-21 00:56:07 - test_mount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 9
- **Tests Failed:** 1
- **Duration:** 16s

**Failed Tests:**
- Test 7: Mount in quiet mode produces minimal output


### 2025-11-21 00:55:12 - test_mount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 1
- **Duration:** 9s

**Failed Tests:**
- Test 7: Mount in quiet mode produces minimal output


### 2025-11-21 00:54:20 - test_mount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 9
- **Tests Failed:** 1
- **Duration:** 20s

**Failed Tests:**
- Test 7: Mount in quiet mode produces minimal output


### 2025-11-21 00:53:04 - test_mount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 10s

**Failed Tests:**
- Test 7: Mount in quiet mode produces minimal output


### 2025-11-21 00:52:45 - test_mount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 10s

**Failed Tests:**
- Test 3: Mount with explicit path parameter


### 2025-11-21 00:52:31 - test_mount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 12s

**Failed Tests:**
- Test 1: Mount VHD with default configuration


### 2025-11-21 00:52:04 - test_mount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 27s

**Failed Tests:**
- Test 1: Mount VHD with default configuration
- Test 3: Mount with explicit path parameter
- Test 7: Mount in quiet mode produces minimal output


### 2025-11-21 00:51:12 - test_mount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 2
- **Tests Failed:** 8
- **Duration:** 0s

**Failed Tests:**
- Test 1: Mount VHD with default configuration
- Test 2: Mount already-mounted VHD (idempotency)
- Test 3: Mount with explicit path parameter
- Test 4: Mount with custom mount point
- Test 6: Mount creates mount point directory
- Test 8: Mount point is accessible after mounting
- Test 9: Mounted filesystem has correct permissions
- Test 10: Status shows VHD as mounted after mount


### 2025-11-21 00:50:41 - test_detach.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 35s


### 2025-11-21 00:49:43 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 9
- **Tests Failed:** 1
- **Duration:** 35s

**Failed Tests:**
- Test 3: Detach already-detached VHD (idempotency)


### 2025-11-21 00:47:18 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 1
- **Duration:** 19s

**Failed Tests:**
- Test 3: Detach already-detached VHD (idempotency)


### 2025-11-21 00:46:36 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 9
- **Tests Failed:** 1
- **Duration:** 30s

**Failed Tests:**
- Test 3: Detach already-detached VHD (idempotency)


### 2025-11-21 00:45:34 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 19s

**Failed Tests:**
- Test 3: Detach already-detached VHD (idempotency)
- Test 4: Detach command executes without error
- Test 10: Detach command completes successfully


### 2025-11-21 00:43:24 - test_detach.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 2
- **Tests Failed:** 0
- **Duration:** 13s


### 2025-11-21 00:43:01 - test_detach.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 0
- **Duration:** 14s


### 2025-11-21 00:42:36 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 19s

**Failed Tests:**
- Test 3: Detach already-detached VHD (idempotency)
- Test 4: Detach command executes without error
- Test 10: Detach command completes successfully


### 2025-11-21 00:41:41 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 2
- **Tests Failed:** 2
- **Duration:** 18s

**Failed Tests:**
- Test 3: Detach already-detached VHD (idempotency)
- Test 4: VHD is detached from WSL after detach


### 2025-11-21 00:40:05 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 12s

**Failed Tests:**
- Test 4: VHD is detached from WSL after detach


### 2025-11-21 00:39:51 - test_detach.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 0
- **Duration:** 14s


### 2025-11-21 00:39:27 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 19s

**Failed Tests:**
- Test 3: Detach already-detached VHD (idempotency)
- Test 4: VHD is detached from WSL after detach
- Test 10: Status shows VHD as not attached after detach


### 2025-11-21 00:38:06 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 10s

**Failed Tests:**
- Test 1: Detach VHD that is attached but not mounted


### 2025-11-21 00:37:47 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 3
- **Tests Failed:** 7
- **Duration:** 13s

**Failed Tests:**
- Test 1: Detach VHD that is attached but not mounted
- Test 2: Detach VHD that is attached and mounted
- Test 3: Detach already-detached VHD (idempotency)
- Test 4: VHD is detached from WSL after detach
- Test 5: Mount point not accessible after detach
- Test 6: Detach in quiet mode produces minimal output
- Test 10: Status shows VHD as not attached after detach


### 2025-11-21 00:37:08 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 0s

**Failed Tests:**
- Test 1: Detach VHD that is attached but not mounted


### 2025-11-21 00:36:57 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 3
- **Tests Failed:** 7
- **Duration:** 0s

**Failed Tests:**
- Test 1: Detach VHD that is attached but not mounted
- Test 2: Detach VHD that is attached and mounted
- Test 3: Detach already-detached VHD (idempotency)
- Test 4: VHD is detached from WSL after detach
- Test 5: Mount point not accessible after detach
- Test 9: Detach in debug mode shows command output
- Test 10: Status shows VHD as not attached after detach


### 2025-11-21 00:34:20 - test_umount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 2
- **Tests Failed:** 8
- **Duration:** 1s

**Failed Tests:**
- Test 1: Umount mounted VHD with default configuration
- Test 2: Umount already-unmounted VHD (idempotency)
- Test 3: Umount with UUID parameter
- Test 4: Umount with path parameter
- Test 5: Umount with mount point parameter
- Test 6: Mount point not accessible after umount
- Test 8: VHD is detached from WSL after umount
- Test 9: Status shows VHD as not mounted after umount


### 2025-11-21 00:34:14 - test_mount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 2
- **Tests Failed:** 8
- **Duration:** 0s

**Failed Tests:**
- Test 1: Mount VHD with default configuration
- Test 2: Mount already-mounted VHD (idempotency)
- Test 3: Mount with explicit path parameter
- Test 4: Mount with custom mount point
- Test 6: Mount creates mount point directory
- Test 8: Mount point is accessible after mounting
- Test 9: Mounted filesystem has correct permissions
- Test 10: Status shows VHD as mounted after mount


### 2025-11-21 00:34:03 - test_detach.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 3
- **Tests Failed:** 7
- **Duration:** 1s

**Failed Tests:**
- Test 1: Detach VHD that is attached but not mounted
- Test 2: Detach VHD that is attached and mounted
- Test 3: Detach already-detached VHD (idempotency)
- Test 4: VHD is detached from WSL after detach
- Test 5: Mount point not accessible after detach
- Test 9: Detach in debug mode shows command output
- Test 10: Status shows VHD as not attached after detach


### 2025-11-21 00:33:35 - test_delete.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 2s


### 2025-11-21 00:33:26 - test_create.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 7s


### 2025-11-21 00:33:08 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 13s


### 2025-11-20 23:34:44 - test_delete.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 5s


### 2025-11-20 23:34:31 - test_delete.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 2
- **Tests Failed:** 0
- **Duration:** 4s


### 2025-11-20 23:34:06 - test_delete.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 8
- **Tests Failed:** 2
- **Duration:** 5s

**Failed Tests:**
- Test 8: Create, detach, and delete a VHD
- Test 9: Verify temp VHD is removed


### 2025-11-20 23:33:30 - test_delete.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 2s

**Failed Tests:**
- Test 8: Create, detach, and delete a VHD


### 2025-11-20 23:33:13 - test_delete.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 2s

**Failed Tests:**
- Test 1: Attempt to delete attached VHD (should fail)


### 2025-11-20 23:33:02 - test_delete.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 2s

**Failed Tests:**
- Test 1: Attempt to delete attached VHD (should fail)
- Test 8: Create, detach, and delete a VHD
- Test 9: Verify temp VHD is removed


### 2025-11-20 23:31:49 - test_delete.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 0s

**Failed Tests:**
- Test 2: Delete detached VHD by path


### 2025-11-20 23:31:40 - test_delete.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 6
- **Tests Failed:** 4
- **Duration:** 0s

**Failed Tests:**
- Test 2: Delete detached VHD by path
- Test 4: Delete detached VHD with --force flag
- Test 5: Delete in quiet mode
- Test 8: Create, detach, and delete a VHD


### 2025-11-20 23:31:04 - test_delete.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 6
- **Tests Failed:** 4
- **Duration:** 1s

**Failed Tests:**
- Test 2: Delete detached VHD by path
- Test 4: Delete detached VHD with --force flag
- Test 5: Delete in quiet mode
- Test 8: Create, detach, and delete a VHD


### 2025-11-20 23:30:40 - test_create.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 6s


### 2025-11-20 23:24:56 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 11s


### 2025-11-20 23:24:07 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 0
- **Duration:** 11s


### 2025-11-20 23:22:15 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 13s


### 2025-11-20 23:21:38 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 0
- **Duration:** 7s


### 2025-11-20 23:16:17 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 8s

**Failed Tests:**
- Test 2: Status with specific UUID


### 2025-11-20 23:14:49 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 0
- **Duration:** 3s


### 2025-11-20 23:09:47 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 0
- **Duration:** 3s


### 2025-11-20 23:09:40 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 0
- **Duration:** 3s


### 2025-11-20 23:09:32 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 0
- **Duration:** 3s


### 2025-11-20 23:07:55 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 3s

**Failed Tests:**
- Test 3: Status with specific path
- Test 4: Status with specific mount point
- Test 5: Status shows attached but not mounted


### 2025-11-20 23:07:42 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 4s

**Failed Tests:**
- Test 3: Status with specific path
- Test 4: Status with specific mount point
- Test 5: Status shows attached but not mounted


### 2025-11-20 23:02:09 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 5s

**Failed Tests:**
- Test 3: Status with specific path
- Test 4: Status with specific mount point
- Test 5: Status shows attached but not mounted


### 2025-11-20 22:59:53 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 4s

**Failed Tests:**
- Test 3: Status with specific path
- Test 4: Status with specific mount point
- Test 5: Status shows attached but not mounted


### 2025-11-20 22:59:33 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 4s

**Failed Tests:**
- Test 3: Status with specific path
- Test 4: Status with specific mount point
- Test 5: Status shows attached but not mounted


### 2025-11-20 22:22:39 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 10s

**Failed Tests:**
- Test 4: Status with specific mount point


### 2025-11-20 22:22:15 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 1
- **Tests Failed:** 0
- **Duration:** 11s


### 2025-11-20 22:20:16 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 2
- **Duration:** 8s

**Failed Tests:**
- Test 2: Status with specific UUID
- Test 4: Status with specific mount point


### 2025-11-20 22:19:58 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 8
- **Tests Failed:** 2
- **Duration:** 9s

**Failed Tests:**
- Test 2: Status with specific UUID
- Test 4: Status with specific mount point


### 2025-11-20 22:18:32 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 8
- **Tests Failed:** 2
- **Duration:** 7s

**Failed Tests:**
- Test 2: Status with specific UUID
- Test 4: Status with specific mount point


### 2025-11-20 22:17:29 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 8
- **Tests Failed:** 2
- **Duration:** 7s

**Failed Tests:**
- Test 2: Status with specific UUID
- Test 4: Status with specific mount point


### 2025-11-20 20:28:25 - test_umount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 8s

**Failed Tests:**
- Test 1: Umount mounted VHD with default configuration


### 2025-11-20 20:18:26 - test_umount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 8s

**Failed Tests:**
- Test 1: Umount mounted VHD with default configuration


### 2025-11-20 20:18:11 - test_umount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 2
- **Tests Failed:** 8
- **Duration:** 8s

**Failed Tests:**
- Test 1: Umount mounted VHD with default configuration
- Test 2: Umount already-unmounted VHD (idempotency)
- Test 3: Umount with UUID parameter
- Test 4: Umount with path parameter
- Test 5: Umount with mount point parameter
- Test 6: Mount point not accessible after umount
- Test 8: VHD is detached from WSL after umount
- Test 9: Status shows VHD as not mounted after umount


### 2025-11-20 19:18:33 - test_mount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 7s

**Failed Tests:**
- Test 4: Mount with custom mount point
- Test 6: Mount creates mount point directory
- Test 10: Status shows VHD as mounted after mount


### 2025-11-20 19:18:26 - test_create.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 9
- **Tests Failed:** 1
- **Duration:** 5s

**Failed Tests:**
- Test 8: Create VHD with 2G size


### 2025-11-20 19:10:34 - test_create.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 6s


### 2025-11-20 19:09:31 - test_create.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 0
- **Tests Failed:** 1
- **Duration:** 1s

**Failed Tests:**
- Test 8: Create VHD with 2G size


### 2025-11-20 19:09:21 - test_create.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 9
- **Tests Failed:** 1
- **Duration:** 5s

**Failed Tests:**
- Test 8: Create VHD with 2G size


### 2025-11-20 18:54:59 - test_mount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 8s

**Failed Tests:**
- Test 4: Mount with custom mount point
- Test 6: Mount creates mount point directory
- Test 10: Status shows VHD as mounted after mount


### 2025-11-20 18:54:51 - test_create.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 6s


### 2025-11-20 18:53:48 - test_mount.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 7
- **Tests Failed:** 3
- **Duration:** 11s

**Failed Tests:**
- Test 4: Mount with custom mount point
- Test 6: Mount creates mount point directory
- Test 10: Status shows VHD as mounted after mount


### 2025-11-20 18:53:18 - test_create.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 9s


### 2025-11-20 18:52:30 - test_create.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 2
- **Tests Failed:** 1
- **Duration:** 1s

**Failed Tests:**
- Test 3: Verify created VHD is NOT attached


### 2025-11-20 18:51:42 - test_create.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 9
- **Tests Failed:** 1
- **Duration:** 9s

**Failed Tests:**
- Test 3: Verify created VHD is NOT attached


### 2025-11-20 16:02:36 - test_status.sh

- **Status:** ✓ PASSED
- **Tests Run:** 10
- **Tests Passed:** 10
- **Tests Failed:** 0
- **Duration:** 25s


### 2025-11-20 16:00:48 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 8
- **Tests Failed:** 2
- **Duration:** 13s

**Failed Tests:**
- Test 3: Status with specific path
- Test 4: Status with specific mount point


### 2025-11-20 15:00:59 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 8
- **Tests Failed:** 2
- **Duration:** 7s

**Failed Tests:**
- Test 3: Status with specific path
- Test 4: Status with specific mount point


### 2025-11-20 14:59:48 - test_status.sh

- **Status:** ✗ FAILED
- **Tests Run:** 10
- **Tests Passed:** 8
- **Tests Failed:** 2
- **Duration:** 4s

**Failed Tests:**
- Test 3: Status with specific path
- Test 4: Status with specific mount point


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
