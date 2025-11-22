# WSL VHD Disk Management - Test Report

Last Updated: 2025-11-22 23:36:18

<a id="test-suite-summary"></a>
## Test Suite Summary

| Test Suite | Last Run | Status | Tests Run | Passed | Failed | Duration |
|------------|----------|--------|-----------|--------|--------|----------|
| [test_attach.sh](#test-attach) | 2025-11-22 | <span style="color: red; font-weight: bold;">✗ FAILED</span> | 15 | 9 | 6 | 14s |
| [test_create.sh](#test-create) | 2025-11-22 | <span style="color: red; font-weight: bold;">✗ FAILED</span> | 10 | 1 | 9 | 1s |
| [test_delete.sh](#test-delete) | 2025-11-22 | <span style="color: red; font-weight: bold;">✗ FAILED</span> | 10 | 6 | 4 | 3s |
| [test_detach.sh](#test-detach) | 2025-11-22 | <span style="color: red; font-weight: bold;">✗ FAILED</span> | 10 | 3 | 7 | 11s |
| [test_mount.sh](#test-mount) | 2025-11-22 | <span style="color: red; font-weight: bold;">✗ FAILED</span> | 10 | 2 | 8 | 12s |
| [test_resize.sh](#test-resize) | 2025-11-22 | <span style="color: red; font-weight: bold;">✗ FAILED</span> | 20 | 4 | 16 | 2s |
| [test_status.sh](#test-status) | 2025-11-22 | <span style="color: red; font-weight: bold;">✗ FAILED</span> | 10 | 0 | 1 | 8s |
| [test_umount.sh](#test-umount) | 2025-11-22 | <span style="color: red; font-weight: bold;">✗ FAILED</span> | 10 | 2 | 8 | 14s |

<a id="test-attach"></a>
### test_attach.sh ![FAILED](https://img.shields.io/badge/status-FAILED-red)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✗ FAILED |
| **Tests Run** | 15 |
| **Passed** | <span style="color: green;">9</span> |
| **Failed** | <span style="color: red;">6</span> |
| **Duration** | 14s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Test 1 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **2** | Test 2 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **3** | Test 3 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **4** | Verify attached VHD appears in status | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **5** | Verify VHD is not mounted after attach | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **6** | Test 6 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **7** | Attach in debug mode shows commands | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **8** | Test 8 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **9** | Test 9 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **10** | Test 10 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **11** | UUID is detected and reported after attach | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **12** | Device name is reported after attach | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **13** | Attach shows completion message | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **14** | Test 14 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **15** | Test 15 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |

<a id="test-create"></a>
### test_create.sh ![FAILED](https://img.shields.io/badge/status-FAILED-red)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✗ FAILED |
| **Tests Run** | 10 |
| **Passed** | <span style="color: green;">1</span> |
| **Failed** | <span style="color: red;">9</span> |
| **Duration** | 1s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Create VHD with default settings | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **2** | Verify created VHD file exists | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **3** | Verify created VHD file can be found | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **4** | Create VHD with custom size (500M) | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **5** | Verify custom size VHD exists | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **6** | Create VHD in quiet mode | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Create VHD with 2G size | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **9** | Verify custom VHD file exists | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **10** | Attach created VHD | <span style="color: red; font-weight: bold;">✗ FAILED</span> |

<a id="test-delete"></a>
### test_delete.sh ![FAILED](https://img.shields.io/badge/status-FAILED-red)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✗ FAILED |
| **Tests Run** | 10 |
| **Passed** | <span style="color: green;">6</span> |
| **Failed** | <span style="color: red;">4</span> |
| **Duration** | 3s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Test 1 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **2** | Delete detached VHD by path | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **3** | Test 3 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **4** | Delete detached VHD with --force flag | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **5** | Delete in quiet mode | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **6** | Test 6 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Create, detach, and delete a VHD | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **9** | Test 9 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **10** | Test 10 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |

<a id="test-detach"></a>
### test_detach.sh ![FAILED](https://img.shields.io/badge/status-FAILED-red)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✗ FAILED |
| **Tests Run** | 10 |
| **Passed** | <span style="color: green;">3</span> |
| **Failed** | <span style="color: red;">7</span> |
| **Duration** | 11s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Detach VHD that is attached but not mounted | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **2** | Detach VHD that is attached and mounted | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **3** | Detach already-detached VHD shows appropriate error | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **4** | Detach command executes without error | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **5** | Mount point not accessible after detach | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **6** | Test 6 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Test 8 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **9** | Detach in debug mode shows command output | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **10** | Detach command completes successfully | <span style="color: red; font-weight: bold;">✗ FAILED</span> |

<a id="test-mount"></a>
### test_mount.sh ![FAILED](https://img.shields.io/badge/status-FAILED-red)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✗ FAILED |
| **Tests Run** | 10 |
| **Passed** | <span style="color: green;">2</span> |
| **Failed** | <span style="color: red;">8</span> |
| **Duration** | 12s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Mount VHD with default configuration | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **2** | Mount already-mounted VHD (idempotency) | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **3** | Mount with explicit path parameter | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **4** | Mount with custom mount point | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **5** | Test 5 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **6** | Mount creates mount point directory | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Mount point is accessible after mounting | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **9** | Mounted filesystem has correct permissions | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **10** | Status shows VHD as mounted after mount | <span style="color: red; font-weight: bold;">✗ FAILED</span> |

<a id="test-resize"></a>
### test_resize.sh ![FAILED](https://img.shields.io/badge/status-FAILED-red)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✗ FAILED |
| **Tests Run** | 20 |
| **Passed** | <span style="color: green;">4</span> |
| **Failed** | <span style="color: red;">16</span> |
| **Duration** | 2s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Test 1 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **2** | Test 2 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **3** | Test 3 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **4** | Test 4 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **5** | Test 5 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **6** | Test 6 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Test 8 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **9** | Test 9 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **10** | Test 10 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **11** | Test 11 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **12** | Test 12 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **13** | Test 13 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **14** | Test 14 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **15** | Test 15 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **16** | Test 16 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **17** | Test 17 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **18** | Test 18 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **19** | Test 19 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **20** | Test 20 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |

<a id="test-status"></a>
### test_status.sh ![FAILED](https://img.shields.io/badge/status-FAILED-red)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✗ FAILED |
| **Tests Run** | 10 |
| **Passed** | <span style="color: green;">0</span> |
| **Failed** | <span style="color: red;">1</span> |
| **Duration** | 8s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **2** | Status with specific UUID | <span style="color: red; font-weight: bold;">✗ FAILED</span> |

<a id="test-umount"></a>
### test_umount.sh ![FAILED](https://img.shields.io/badge/status-FAILED-red)

[↑ Back to Summary](#test-suite-summary)

| Metric | Value |
|--------|-------|
| **Last Run** | 2025-11-22 |
| **Status** | ✗ FAILED |
| **Tests Run** | 10 |
| **Passed** | <span style="color: green;">2</span> |
| **Failed** | <span style="color: red;">8</span> |
| **Duration** | 14s |

#### Test Results

| # | Test Name | Status |
|---|-----------|--------|
| **1** | Umount mounted VHD with default configuration | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **2** | Umount already-unmounted VHD (idempotency) | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **3** | Umount with UUID parameter | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **4** | Umount with path parameter | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **5** | Umount with mount point parameter | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **6** | Mount point not accessible after umount | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **7** | Test 7 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |
| **8** | Umount command completes successfully | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **9** | Umount reports successful completion | <span style="color: red; font-weight: bold;">✗ FAILED</span> |
| **10** | Test 10 | <span style="color: green; font-weight: bold;">✓ PASSED</span> |

---
*This report is automatically generated and updated when test suites are executed.*
